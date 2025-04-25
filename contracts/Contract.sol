// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


contract NGODonation {
    address public owner;
    
    // NGO status
    enum NGOStatus { Unregistered, Pending, Verified, Suspended }
    
    // NGO structure
    struct NGO {
        string name;
        address payable walletAddress;
        string description;
        uint256 totalDonations;
        NGOStatus status;
        uint256 registrationTime;
    }
    
    // Donation structure
    struct Donation {
        address donor;
        address ngo;
        uint256 amount;
        uint256 timestamp;
        string projectId; // Optional project ID if donation is for specific project
    }

    // Mappings
    mapping(address => NGO) public registeredNGOs;
    mapping(string => address) public ngoEmailToAddress;
    mapping(address => bool) public verifiers;
    mapping(uint256 => Donation) public donations;
    
    // Counters
    uint256 public totalDonations;
    uint256 public totalNGOs;
    
    // Events
    event NGORegistered(address indexed ngoAddress, string name, uint256 timestamp);
    event NGOVerified(address indexed ngoAddress, uint256 timestamp);
    event NGOSuspended(address indexed ngoAddress, uint256 timestamp);
    event DonationReceived(uint256 indexed donationId, address indexed donor, address indexed ngo, uint256 amount, string projectId, uint256 timestamp);
    event VerifierAdded(address indexed verifier, uint256 timestamp);
    event VerifierRemoved(address indexed verifier, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }
    
    modifier onlyVerifier() {
        require(verifiers[msg.sender] || msg.sender == owner, "Only authorized verifiers can perform this action");
        _;
    }
    
    modifier ngoExists(address ngoAddress) {
        require(registeredNGOs[ngoAddress].registrationTime > 0, "NGO does not exist");
        _;
    }
    
    modifier ngoVerified(address ngoAddress) {
        require(registeredNGOs[ngoAddress].status == NGOStatus.Verified, "NGO is not verified");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        verifiers[msg.sender] = true;
        emit VerifierAdded(msg.sender, block.timestamp);
    }
    
    function registerNGO(
        address payable ngoAddress, 
        string memory name, 
        string memory description,
        string memory email
    ) 
        public 
    {
        require(registeredNGOs[ngoAddress].registrationTime == 0, "NGO address already registered");
        require(ngoEmailToAddress[email] == address(0), "Email already registered");
        
        registeredNGOs[ngoAddress] = NGO({
            name: name,
            walletAddress: ngoAddress,
            description: description,
            totalDonations: 0,
            status: NGOStatus.Pending,
            registrationTime: block.timestamp
        });
        
        ngoEmailToAddress[email] = ngoAddress;
        totalNGOs++;
        
        emit NGORegistered(ngoAddress, name, block.timestamp);
    }
    
    function verifyNGO(address ngoAddress) 
        public 
        onlyVerifier 
        ngoExists(ngoAddress) 
    {
        require(registeredNGOs[ngoAddress].status == NGOStatus.Pending, "NGO is not in pending status");
        
        registeredNGOs[ngoAddress].status = NGOStatus.Verified;
        
        emit NGOVerified(ngoAddress, block.timestamp);
    }

    function suspendNGO(address ngoAddress) 
        public 
        onlyVerifier 
        ngoExists(ngoAddress) 
    {
        require(registeredNGOs[ngoAddress].status == NGOStatus.Verified, "NGO is not verified");
        
        registeredNGOs[ngoAddress].status = NGOStatus.Suspended;
        
        emit NGOSuspended(ngoAddress, block.timestamp);
    }
    
    function donate(address ngoAddress, string memory projectId) 
        public 
        payable 
        ngoExists(ngoAddress) 
        ngoVerified(ngoAddress) 
    {
        require(msg.value > 0, "Donation amount must be greater than 0");
        
        // Update donation count and NGO's total donations
        uint256 donationId = totalDonations;
        totalDonations++;
        registeredNGOs[ngoAddress].totalDonations += msg.value;
        
        // Record the donation
        donations[donationId] = Donation({
            donor: msg.sender,
            ngo: ngoAddress,
            amount: msg.value,
            timestamp: block.timestamp,
            projectId: projectId
        });
        
        // Transfer the funds to the NGO
        registeredNGOs[ngoAddress].walletAddress.transfer(msg.value);
        
        emit DonationReceived(donationId, msg.sender, ngoAddress, msg.value, projectId, block.timestamp);
    }

    function addVerifier(address verifierAddress) 
        public 
        onlyOwner 
    {
        require(!verifiers[verifierAddress], "Address is already a verifier");
        
        verifiers[verifierAddress] = true;
        
        emit VerifierAdded(verifierAddress, block.timestamp);
    }
    
    function removeVerifier(address verifierAddress) 
        public 
        onlyOwner 
    {
        require(verifiers[verifierAddress], "Address is not a verifier");
        require(verifierAddress != owner, "Cannot remove owner as verifier");
        
        verifiers[verifierAddress] = false;
        
        emit VerifierRemoved(verifierAddress, block.timestamp);
    }
    
    function getNGODetails(address ngoAddress) 
        public 
        view 
        ngoExists(ngoAddress) 
        returns (
            string memory name,
            string memory description,
            uint256 totalDonations,
            NGOStatus status,
            uint256 registrationTime
        ) 
    {
        NGO memory ngo = registeredNGOs[ngoAddress];
        return (
            ngo.name,
            ngo.description,
            ngo.totalDonations,
            ngo.status,
            ngo.registrationTime
        );
    }
    
    function getDonationDetails(uint256 donationId) 
        public 
        view 
        returns (
            address donor,
            address ngo,
            uint256 amount,
            uint256 timestamp,
            string memory projectId
        ) 
    {
        require(donationId < totalDonations, "Invalid donation ID");
        
        Donation memory donation = donations[donationId];
        return (
            donation.donor,
            donation.ngo,
            donation.amount,
            donation.timestamp,
            donation.projectId
        );
    }
    
    function getNGOAddressByEmail(string memory email) 
        public 
        view 
        returns (address) 
    {
        address ngoAddress = ngoEmailToAddress[email];
        require(ngoAddress != address(0), "No NGO registered with this email");
        return ngoAddress;
    }
    
    function isVerifier(address verifierAddress) 
        public 
        view 
        returns (bool) 
    {
        return verifiers[verifierAddress];
    }
}