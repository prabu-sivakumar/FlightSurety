pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 MAX_INSURANCE = 1 ether;
    uint256 PAYOUT_PERCENTAGE = 150;

    uint256 VOTING_THRESHOLD = 4;
    uint256 REQUIRED_VOTES = 2;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    mapping(address => address[]) public airlines; 

    FlightSuretyData flightSuretyData;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() {
        require(
            flightSuretyData.isOperational(),
            "Contract is currently not operational"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAirlineIsNotRegistered(address airline) {
        require(
            !flightSuretyData.isAirlineRegistered(airline),
            "Airline is already registered."
        );
        _;
    }

    modifier requireAirlineIsRegistered(address airline) {
        require(
            flightSuretyData.isAirlineRegistered(airline),
            "Airline is not registered."
        );
        _;
    }

    modifier requireAirlineIsNotFunded(address airline) {
        require(
            !flightSuretyData.isAirlineFunded(airline),
            "Airline is already funded."
        );
        _;
    }

    modifier requireAirlineIsFunded(address airline) {
        require(
            flightSuretyData.isAirlineFunded(airline),
            "Airline is not funded."
        );
        _;
    }

    modifier requireFlightIsNotRegistered(bytes32 flightKey) {
        require(
            !flightSuretyData.isFlightRegistered(flightKey),
            "Flight is already registered."
        );
        _;
    }

    modifier requireFlightIsRegistered(bytes32 flightKey) {
        require(
            flightSuretyData.isFlightRegistered(flightKey),
            "Flight is not registered."
        );
        _;
    }

    modifier requireFlightIsNotLanded(bytes32 flightKey) {
        require(
            !flightSuretyData.isFlightLanded(flightKey),
            "Flight has already landed"
        );
        _;
    }

    modifier requireSufficientFund(uint256 amount) {
        require(msg.value >= amount, "Insufficient Funds.");
        _;
    }

    modifier requirePassengerNotInsuredForFlight(
        bytes32 flightKey,
        address passenger
    ) {
        require(
            !flightSuretyData.isPassengerInsuredForFlight(flightKey, passenger),
            "Passenger is already insured."
        );
        _;
    }

    modifier requireLessThanMaxInsurancePlan() {
        require(
            msg.value <= MAX_INSURANCE,
            "Amount Payable exceeds the Maximum Insurance."
        );
        _;
    }

    modifier calculateRefund() {
        _;
        uint256 refund = msg.value - AIRLINE_REGISTRATION_FEE;
        msg.sender.transfer(refund);
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address data) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(data);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function setOperatingStatus(bool mode) external requireContractOwner {
        flightSuretyData.setOperatingStatus(mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address airline)
        external
        requireIsOperational
        requireAirlineIsNotRegistered(airline)
        requireAirlineIsFunded(msg.sender)
        returns (bool success, uint256 votes, uint256 numberOfRegisteredAirlines)
    {
        //Check for the minimum number of Airlines required for Voting Process
        if (
            flightSuretyData.getNumberOfRegisteredAirlines() <= VOTING_THRESHOLD
        ) {
            flightSuretyData.registerAirline(airline, msg.sender);
            return (
                success,
                0,
                flightSuretyData.getNumberOfRegisteredAirlines()
            );
        } else {
            bool hasDuplicate = false;
            for (uint256 index = 0; index < airlines[airline].length; index++) {
                if (airlines[airline][index] == msg.sender) {
                    hasDuplicate = true;
                    break;
                }
            }
            require(
                !hasDuplicate,
                "You cannot vote twice for the same Airline"
            );
            airlines[airline].push(msg.sender);
            if (
                airlines[airline].length >=
                flightSuretyData.getNumberOfRegisteredAirlines().div(
                    REQUIRED_VOTES
                )
            ) {
                flightSuretyData.registerAirline(airline, msg.sender);
                return (
                    true,
                    airlines[airline].length,
                    flightSuretyData.getNumberOfRegisteredAirlines()
                );
            }
            return (
                false,
                airlines[airline].length,
                flightSuretyData.getNumberOfRegisteredAirlines()
            );
        }
    }

    function fundAirline()
        external
        payable
        requireIsOperational
        requireAirlineIsRegistered(msg.sender)
        requireAirlineIsNotFunded(msg.sender)
        requireSufficientFund(AIRLINE_REGISTRATION_FEE)
        returns (bool)
    {
        address(uint160(address(flightSuretyData))).transfer(AIRLINE_REGISTRATION_FEE);
        return flightSuretyData.fund(msg.sender, AIRLINE_REGISTRATION_FEE);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string flightNumber,
        uint256 timestamp,
        string departureCity,
        string arrivalCity
    ) external requireIsOperational requireAirlineIsFunded(msg.sender) {
        bytes32 flightKey = getFlightKey(msg.sender, flightNumber, timestamp);
        flightSuretyData.registerFlight(
            flightKey,
            timestamp,
            msg.sender,
            flightNumber,
            departureCity,
            arrivalCity
        );
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal requireIsOperational {
        flightSuretyData.processFlightStatus(
            airline,
            flight,
            timestamp,
            statusCode
        );
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    function buyInsurance(bytes32 flightKey)
        public
        payable
        requireIsOperational
        requireFlightIsRegistered(flightKey)
        requireFlightIsNotLanded(flightKey)
        requirePassengerNotInsuredForFlight(flightKey, msg.sender)
        requireLessThanMaxInsurancePlan
    {
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.buy(
            flightKey,
            msg.sender,
            msg.value,
            PAYOUT_PERCENTAGE
        );
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

contract FlightSuretyData {
    function isOperational() public view returns (bool);

    function setOperatingStatus(bool mode) external;

    function isAirlineRegistered(address airline) public view returns (bool);

    function isAirlineFunded(address airline) public view returns (bool);

    function isFlightRegistered(bytes32 flightKey) public view returns (bool);

    function isFlightLanded(bytes32 flightKey) public view returns (bool);

    function isPassengerInsuredForFlight(bytes32 flightKey, address passenger)
        public
        view
        returns (bool);

    function registerAirline(address newAirline, address registeringAirline)
        external;

    function fund(address airline, uint256 amount) external returns (bool);

    function getNumberOfRegisteredAirlines() public view returns (uint256);

    function getNumberOfFundedAirlines() public view returns (uint256);

    function registerFlight(
        bytes32 flightKey,
        uint256 timestamp,
        address airline,
        string memory flightNumber,
        string memory departureLocation,
        string memory arrivalLocation
    ) public payable;

    function getNumberOfRegisteredFlights() public view returns (uint256);

    function processFlightStatus(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external;

    function buy(
        bytes32 flightKey,
        address passenger,
        uint256 amount,
        uint256 payout
    ) external payable;

    function creditInsurees(bytes32 flightKey) internal;

    function pay(address payoutAddress) external;

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32);
}
