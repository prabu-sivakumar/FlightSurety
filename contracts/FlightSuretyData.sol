pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    // Struct to declare Airline Information
    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 funds;
    }

    uint256 numberOfRegisteredAirlines = 0;
    uint256 numberOfAirlinesFunded = 0;
    mapping(address => Airline) private airlines; // To store the address of Airline

    //Struct to declare Flight Information
    struct Flight {
        bool isRegistered;
        bytes32 flightKey;
        address airline;
        string flightNumber;
        uint8 statusCode;
        uint256 timestamp;
        string departureCity;
        string arrivalCity;
    }
    mapping(bytes32 => Flight) public flights;
    bytes32[] public registeredFlights;

    //Struct to declare Insurance Claim
    struct InsuranceClaim {
        address passenger;
        uint256 purchaseAmount;
        uint256 payoutPercentage;
        bool credited;
    }
    //Flight Insurance Claims
    mapping(bytes32 => InsuranceClaim[]) public flightInsuranceClaims;

    //Passenger Insurance Claims
    mapping(address => uint256) public availableFundsToWithdraw;

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address airlineAddress) public {
        contractOwner = msg.sender;
        airlines[airlineAddress] = Airline(true, false, 0);
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineRegistered(address airline);
    event AirlineFunded(address airline);
    event FlightRegistered(bytes32 flightKey);
    event ProcessedFlightStatus(bytes32 flightKey, uint8 statusCode);
    event PassengerInsured(
        bytes32 flightKey,
        address passenger,
        uint256 amount,
        uint256 payoutPercentage
    );
    event InsureeCredited(bytes32 flightKey, address passenger, uint256 amount);
    event PayInsuree(address payoutAddress, uint256 amount);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that validates if the Airline is already Registered
     */
    modifier requireAirlineIsNotRegistered(address airline) {
        require(
            !airlines[airline].isRegistered,
            "Airline is already registered."
        );
        _;
    }

    modifier requireAirlineIsRegistered(address airline) {
        require(airlines[airline].isRegistered, "Airline is not registered.");
        _;
    }

    /**
     * @dev Modifier that validates if the Airline is already Funded
     */
    modifier requireAirlineIsNotFunded(address airline) {
        require(!airlines[airline].isFunded, "Airline is already funded.");
        _;
    }

    modifier requireAirlineIsFunded(address airline) {
        require(airlines[airline].isFunded, "Airline is not funded.");
        _;
    }

    /**
     * @dev Modifier that validates if the Flight is already Registered
     */
    modifier requireFlightIsNotRegistered(bytes32 flightKey) {
        require(!flights[flightKey].isRegistered, "Flight is already funded.");
        _;
    }

    modifier requireFlightIsRegistered(bytes32 flightKey) {
        require(
            flights[flightKey].isRegistered,
            "Flight is already registered."
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /**
     * Function to validate if the Flight has landed.
     */
    function isFlightLanded(bytes32 flightKey) public view returns (bool) {
        if (flights[flightKey].statusCode > 0) {
            return true;
        }
        return false;
    }

    function isAirlineRegistered(address airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].isRegistered;
    }

    function isAirlineFunded(address airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].isFunded;
    }

    function isFlightRegistered(bytes32 flightKey)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return flights[flightKey].isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address newAirline, address existingAirline)
        external
        requireIsOperational
        requireAirlineIsNotRegistered(newAirline)
        requireAirlineIsFunded(existingAirline)
    {
        airlines[newAirline] = Airline(true, false, 0);
        numberOfRegisteredAirlines = numberOfRegisteredAirlines.add(1);
        emit AirlineRegistered(newAirline);
    }

    function getNumberOfRegisteredAirlines()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return numberOfRegisteredAirlines;
    }

    function getNumberOfFundedAirlines()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return numberOfAirlinesFunded;
    }

    function registerFlight(
        bytes32 flightKey,
        uint256 timestamp,
        address airline,
        string memory flightNumber,
        string memory departureCity,
        string memory arrivalCity
    )
        public
        payable
        requireIsOperational
        requireAirlineIsFunded(airline)
        requireFlightIsNotRegistered(flightKey)
    {
        flights[flightKey] = Flight(
            true,
            flightKey,
            airline,
            flightNumber,
            0,
            timestamp,
            departureCity,
            arrivalCity
        );
        registeredFlights.push(flightKey);
        emit FlightRegistered(flightKey);
    }

    function processFlightStatus(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(!isFlightLanded(flightKey), "Flight has already landed.");
        if (flights[flightKey].statusCode == 0) {
            flights[flightKey].statusCode = statusCode;
            //STATUS_CODE_LATE_AIRLINE
            if (statusCode == 20) {
                creditInsurees(flightKey);
            }
        }
        emit ProcessedFlightStatus(flightKey, statusCode);
    }

    function getNumberOfRegisteredFlights()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return registeredFlights.length;
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        bytes32 flightKey,
        address passenger,
        uint256 amount,
        uint256 payoutPercentage
    )
        external
        payable
        requireIsOperational
        requireFlightIsRegistered(flightKey)
    {
        require(!isFlightLanded(flightKey), "Flight has already landed");
        flightInsuranceClaims[flightKey].push(
            InsuranceClaim(passenger, amount, payoutPercentage, false)
        );
        emit PassengerInsured(flightKey, passenger, amount, payoutPercentage);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(bytes32 flightKey) internal requireIsOperational {
        for (uint256 i = 0; i < flightInsuranceClaims[flightKey].length; i++) {
            InsuranceClaim memory insuranceClaim = flightInsuranceClaims[
                flightKey
            ][i];
            insuranceClaim.credited = true;
            uint256 amount = insuranceClaim
                .purchaseAmount
                .mul(insuranceClaim.payoutPercentage)
                .div(100);
            availableFundsToWithdraw[
                insuranceClaim.passenger
            ] = availableFundsToWithdraw[insuranceClaim.passenger].add(amount);
            emit InsureeCredited(flightKey, insuranceClaim.passenger, amount);
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address payoutAddress)
        external
        payable
        requireIsOperational
    {
        uint256 amount = availableFundsToWithdraw[payoutAddress];
        require(
            address(this).balance >= amount,
            "Contract has insufficient funds."
        );
        require(amount > 0, "No fund available to withdraw");
        availableFundsToWithdraw[payoutAddress] = 0;
        address(uint160(address(payoutAddress))).transfer(amount);
        emit PayInsuree(payoutAddress, amount);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(address airline, uint256 amount)
        external
        payable
        requireIsOperational
        requireAirlineIsRegistered(airline)
        requireAirlineIsNotFunded(airline)
        returns (bool)
    {
        airlines[airline].isFunded = true;
        airlines[airline].funds = airlines[airline].funds.add(amount);
        numberOfAirlinesFunded = numberOfAirlinesFunded.add(1);
        emit AirlineFunded(airline);
        return airlines[airline].isFunded;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function isPassengerInsuredForFlight(bytes32 flightKey, address passenger)
        public
        view
        returns (bool)
    {
        InsuranceClaim[] memory insuranceClaims = flightInsuranceClaims[
            flightKey
        ];
        for (uint256 i = 0; i < insuranceClaims.length; i++) {
            if (insuranceClaims[i].passenger == passenger) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
    }
}
