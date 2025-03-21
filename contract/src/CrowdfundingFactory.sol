// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Crowdfunding} from "./Crowdfunding.sol";

/**
 * @title CrowdfundingFactory
 * @dev Factory contract for creating and managing multiple Crowdfunding campaigns
 * @notice Enables users to create crowdfunding campaigns and tracks all created campaigns
 */
contract CrowdfundingFactory {
    // Contract state
    address public owner;
    bool public paused;

    /**
     * @dev Structure to store essential campaign information
     */
    struct Campaign {
        address campaignAddress;  // Address of the deployed campaign contract
        address owner;            // Address of the campaign creator
        string name;              // Name of the campaign
        uint256 creationTime;     // Timestamp when the campaign was created
    }

    // Storage variables
    Campaign[] public campaigns;
    mapping(address => Campaign[]) public userCampaigns;

    /**
     * @dev Restricts function access to the factory contract owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner.");
        _;
    }

    /**
     * @dev Prevents execution when the factory contract is paused
     */
    modifier notPaused() {
        require(!paused, "Factory is paused");
        _;
    }

    /**
     * @dev Constructor sets the deployer as the factory owner
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Creates a new crowdfunding campaign
     * @param _name Name of the crowdfunding campaign
     * @param _description Detailed description of the campaign
     * @param _goal Funding target in wei
     * @param _durationInDays Duration of the campaign in days
     * @notice Deploys a new Crowdfunding contract and tracks it in the factory
     */
    function createCampaign(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external notPaused {
        Crowdfunding newCampaign = new Crowdfunding(
            msg.sender,
            _name,
            _description,
            _goal,
            _durationInDays
        );
        
        address campaignAddress = address(newCampaign);
        Campaign memory campaign = Campaign({
            campaignAddress: campaignAddress,
            owner: msg.sender,
            name: _name,
            creationTime: block.timestamp
        });
        
        campaigns.push(campaign);
        userCampaigns[msg.sender].push(campaign);
    }

    /**
     * @dev Retrieves all campaigns created by a specific user
     * @param _user Address of the user whose campaigns to retrieve
     * @return Array of Campaign structs created by the specified user
     */
    function getUserCampaigns(address _user) external view returns (Campaign[] memory) {
        return userCampaigns[_user];
    }

    /**
     * @dev Retrieves all campaigns created through this factory
     * @return Array of all Campaign structs
     */
    function getAllCampaigns() external view returns (Campaign[] memory) {
        return campaigns;
    }

    /**
     * @dev Allows the owner to pause or unpause the factory
     * @notice Toggles the paused state to prevent or allow new campaign creation
     */
    function togglePause() external onlyOwner {
        paused = !paused;
    }
}