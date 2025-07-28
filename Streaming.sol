// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralizedMusicStreaming
 * @dev Smart contract for decentralized music streaming platform
 * @author Your Name
 */
contract DecentralizedMusicStreaming {
    
    // Struct to store track information
    struct Track {
        uint256 id;
        string title;
        string artist;
        string ipfsHash;          // IPFS hash for the music file
        uint256 pricePerStream;   // Price in wei per stream
        address payable owner;    // Artist's wallet address
        uint256 totalStreams;     // Total number of streams
        uint256 totalEarnings;    // Total earnings from this track
        bool isActive;            // Track availability status
        uint256 uploadTime;       // Timestamp when track was uploaded
    }
    
    // State variables
    mapping(uint256 => Track) public tracks;
    mapping(address => uint256[]) public artistTracks;  // Artist to their track IDs
    mapping(address => mapping(uint256 => bool)) public hasStreamedTrack; // User streaming history
    mapping(address => uint256) public userStreamCount; // Total streams per user
    
    uint256 public trackCounter;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    address payable public platformOwner;
    
    // Events
    event TrackUploaded(uint256 indexed trackId, string title, address indexed artist, uint256 pricePerStream);
    event TrackStreamed(uint256 indexed trackId, address indexed listener, uint256 amount);
    event EarningsWithdrawn(address indexed artist, uint256 amount);
    event TrackDeactivated(uint256 indexed trackId);
    event PlatformFeeUpdated(uint256 newFeePercentage);
    
    // Modifiers
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }
    
    modifier onlyTrackOwner(uint256 _trackId) {
        require(tracks[_trackId].owner == msg.sender, "Only track owner can call this function");
        _;
    }
    
    modifier trackExists(uint256 _trackId) {
        require(tracks[_trackId].id != 0, "Track does not exist");
        _;
    }
    
    modifier trackActive(uint256 _trackId) {
        require(tracks[_trackId].isActive, "Track is not active");
        _;
    }
    
    // Constructor
    constructor() {
        platformOwner = payable(msg.sender);
        trackCounter = 0;
    }
    
    /**
     * @dev Upload a new music track to the platform
     * @param _title Title of the track
     * @param _artist Artist name
     * @param _ipfsHash IPFS hash of the music file
     * @param _pricePerStream Price per stream in wei
     */
    function uploadTrack(
        string memory _title,
        string memory _artist,
        string memory _ipfsHash,
        uint256 _pricePerStream
    ) external {
        require(bytes(_title).length > 0, "Track title cannot be empty");
        require(bytes(_artist).length > 0, "Artist name cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(_pricePerStream > 0, "Price per stream must be greater than 0");
        
        trackCounter++;
        
        tracks[trackCounter] = Track({
            id: trackCounter,
            title: _title,
            artist: _artist,
            ipfsHash: _ipfsHash,
            pricePerStream: _pricePerStream,
            owner: payable(msg.sender),
            totalStreams: 0,
            totalEarnings: 0,
            isActive: true,
            uploadTime: block.timestamp
        });
        
        artistTracks[msg.sender].push(trackCounter);
        
        emit TrackUploaded(trackCounter, _title, msg.sender, _pricePerStream);
    }
    
    /**
     * @dev Stream a track by paying the required fee
     * @param _trackId ID of the track to stream
     */
    function streamTrack(uint256 _trackId) external payable trackExists(_trackId) trackActive(_trackId) {
        Track storage track = tracks[_trackId];
        require(msg.value >= track.pricePerStream, "Insufficient payment for streaming");
        require(track.owner != msg.sender, "Artists cannot stream their own tracks");
        
        // Calculate platform fee and artist earnings
        uint256 platformFee = (msg.value * platformFeePercentage) / 100;
        uint256 artistEarnings = msg.value - platformFee;
        
        // Update track statistics
        track.totalStreams++;
        track.totalEarnings += artistEarnings;
        
        // Update user statistics
        if (!hasStreamedTrack[msg.sender][_trackId]) {
            hasStreamedTrack[msg.sender][_trackId] = true;
        }
        userStreamCount[msg.sender]++;
        
        // Transfer payments
        track.owner.transfer(artistEarnings);
        platformOwner.transfer(platformFee);
        
        // Refund excess payment if any
        if (msg.value > track.pricePerStream) {
            payable(msg.sender).transfer(msg.value - track.pricePerStream);
        }
        
        emit TrackStreamed(_trackId, msg.sender, msg.value);
    }
    
    /**
     * @dev Get detailed information about a specific track
     * @param _trackId ID of the track
     * @return Track struct containing all track information
     */
    function getTrackDetails(uint256 _trackId) external view trackExists(_trackId) returns (Track memory) {
        return tracks[_trackId];
    }
    
    /**
     * @dev Get all track IDs uploaded by a specific artist
     * @param _artist Address of the artist
     * @return Array of track IDs
     */
    function getArtistTracks(address _artist) external view returns (uint256[] memory) {
        return artistTracks[_artist];
    }
    
    /**
     * @dev Deactivate a track (only track owner can do this)
     * @param _trackId ID of the track to deactivate
     */
    function deactivateTrack(uint256 _trackId) external trackExists(_trackId) onlyTrackOwner(_trackId) {
        tracks[_trackId].isActive = false;
        emit TrackDeactivated(_trackId);
    }
    
    /**
     * @dev Update platform fee percentage (only platform owner)
     * @param _newFeePercentage New fee percentage (0-100)
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyPlatformOwner {
        require(_newFeePercentage <= 100, "Fee percentage cannot exceed 100%");
        platformFeePercentage = _newFeePercentage;
        emit PlatformFeeUpdated(_newFeePercentage);
    }
    
    // View functions for frontend integration
    function getTotalTracks() external view returns (uint256) {
        return trackCounter;
    }
    
    function getUserStreamHistory(address _user, uint256 _trackId) external view returns (bool) {
        return hasStreamedTrack[_user][_trackId];
    }
    
    function getUserTotalStreams(address _user) external view returns (uint256) {
        return userStreamCount[_user];
    }
    
    // Emergency function to withdraw contract balance (only platform owner)
    function emergencyWithdraw() external onlyPlatformOwner {
        platformOwner.transfer(address(this).balance);
    }
}
