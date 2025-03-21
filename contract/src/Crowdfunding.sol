// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title Crowdfunding
 * @dev A smart contract for managing crowdfunding campaigns with funding tiers
 * @notice Allows campaign creators to set up tiers, collect funds, and backers to contribute
 */
contract Crowdfunding {
    // Campaign details
    string public name;
    string public description;
    uint256 public goal;
    uint256 public deadline;
    address public owner;
    bool public paused;

    /**
     * @dev Enum representing the possible states of the campaign
     */
    enum CampaignState {
        Active,
        Successful,
        Failed
    }
    CampaignState public state;

    /**
     * @dev Structure defining a funding tier with a name, contribution amount, and counter for backers
     */
    struct Tier {
        string name;
        uint256 amount;
        uint256 backers;
    }

    /**
     * @dev Structure tracking a backer's contributions and the tiers they've funded
     */
    struct Backer {
        uint256 totalContribution;
        mapping(uint256 => bool) fundedTiers; // Maps tier index to funding status
    }

    // Storage variables
    Tier[] public tiers;
    mapping(address => Backer) public backers;

    /**
     * @dev Restricts function access to the campaign owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    /**
     * @dev Ensures the campaign is still active
     */
    modifier campaignOpen() {
        require(state == CampaignState.Active, "Campaign is not active.");
        _;
    }

    /**
     * @dev Prevents execution when the contract is paused
     */
    modifier notPaused() {
        require(!paused, "Contract is paused.");
        _;
    }

    /**
     * @dev Constructor initializes the crowdfunding campaign
     * @param _owner Address of the campaign owner
     * @param _name Name of the crowdfunding campaign
     * @param _description Detailed description of the campaign
     * @param _goal Funding target in wei
     * @param _durationInDays Duration of the campaign in days (typo in parameter name)
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) {
        name = _name;
        description = _description;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
        owner = _owner;
        state = CampaignState.Active;
    }

    /**
     * @dev Internal function to check and update the campaign state based on current conditions
     * @notice Updates state to Successful if goal is met, Failed if deadline passed and goal not met
     */
    function checkAndUpdateCampaignState() internal {
        if (state == CampaignState.Active) {
            if (block.timestamp >= deadline) {
                state = address(this).balance >= goal
                    ? CampaignState.Successful
                    : CampaignState.Failed;
            } else {
                state = address(this).balance >= goal
                    ? CampaignState.Successful
                    : CampaignState.Active;
            }
        }
    }

    /**
     * @dev Allows a user to fund the campaign at a specific tier
     * @param _tierIndex Index of the tier the backer wants to fund
     * @notice Requires the exact amount for the selected tier
     */
    function fund(uint256 _tierIndex) public payable campaignOpen notPaused {
        require(_tierIndex < tiers.length, "Invalid tier.");
        require(msg.value == tiers[_tierIndex].amount, "Incorrect amount.");

        tiers[_tierIndex].backers++;
        backers[msg.sender].totalContribution += msg.value;
        backers[msg.sender].fundedTiers[_tierIndex] = true;

        checkAndUpdateCampaignState();
    }

    /**
     * @dev Allows the owner to add a new funding tier
     * @param _name Name or description of the tier
     * @param _amount Contribution amount required for this tier in wei
     */
    function addTier(string memory _name, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be greater than 0.");
        tiers.push(Tier(_name, _amount, 0));
    }

    /**
     * @dev Allows the owner to remove a funding tier
     * @param _index Index of the tier to remove
     * @notice Removes by replacing with the last tier and popping the array
     */
    function removeTier(uint256 _index) public onlyOwner {
        require(_index < tiers.length, "Tier does not exist.");
        tiers[_index] = tiers[tiers.length - 1];
        tiers.pop();
    }

    /**
     * @dev Allows the owner to withdraw funds if the campaign was successful
     * @notice Transfers the entire contract balance to the owner
     */
    function withdraw() public onlyOwner {
        checkAndUpdateCampaignState();
        require(state == CampaignState.Successful, "Campaign not successful.");

        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        payable(owner).transfer(balance);
    }

    /**
     * @dev Returns the current balance of the contract
     * @return Contract balance in wei
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Allows backers to claim refunds if the campaign failed
     * @notice Refunds the total contribution of the calling backer
     */
    function refund() public {
        checkAndUpdateCampaignState();
        require(state == CampaignState.Failed, "Refunds not available.");
        uint256 amount = backers[msg.sender].totalContribution;
        require(amount > 0, "No contribution to refund");

        backers[msg.sender].totalContribution = 0;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Checks if an address has funded a specific tier
     * @param _backer Address of the backer to check
     * @param _tierIndex Index of the tier to check
     * @return Boolean indicating whether the backer has funded the specified tier
     */
    function hasFundedTier(
        address _backer,
        uint256 _tierIndex
    ) public view returns (bool) {
        return backers[_backer].fundedTiers[_tierIndex];
    }

    /**
     * @dev Returns all tiers of the campaign
     * @return Array of all tier structures
     */
    function getTiers() public view returns (Tier[] memory) {
        return tiers;
    }

    /**
     * @dev Allows the owner to pause or unpause the contract
     * @notice Toggles the paused state to prevent or allow funding
     */
    function togglePause() public onlyOwner {
        paused = !paused;
    }

    /**
     * @dev Gets the current campaign status, calculating it if necessary
     * @return Current state of the campaign (Active, Successful, or Failed)
     */
    function getCampaignStatus() public view returns (CampaignState) {
        if (state == CampaignState.Active && block.timestamp > deadline) {
            return
                address(this).balance >= goal
                    ? CampaignState.Successful
                    : CampaignState.Failed;
        }
        return state;
    }

    /**
     * @dev Allows the owner to extend the deadline of an active campaign
     * @param _daysToAdd Number of days to add to the current deadline
     */
    function extendDeadline(uint256 _daysToAdd) public onlyOwner campaignOpen {
        deadline += _daysToAdd * 1 days;
    }
}
