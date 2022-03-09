//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract HashedTimelock {
    struct LockContract {
        address payable sender;
        address payable receiver;
        uint256 amount;
        bytes32 hashlock; // sha-2 sha256 hash
        uint256 timelock; // UNIX timestamp seconds - locked UNTIL this time
        bool withdrawn;
        bool refunded;
        bytes32 preimage;
    }

    modifier fundsSent() {
        require(msg.value > 0, "msg.value must be > 0");
        _;
    }
    modifier futureTimelock(uint256 _time) {
        require(_time > block.timestamp, "timelock time must be in the future");
        _;
    }

    modifier hashlockMatches(bytes32 _contractId, bytes32 _x) {
        require(
            contracts[_contractId].hashlock == keccak256(abi.encodePacked(_x)),
            "hashlock hash does not match"
        );
        _;
    }
    modifier withdrawable(bytes32 _contractId) {
        require(
            contracts[_contractId].receiver == msg.sender,
            "withdrawable: not receiver"
        );
        require(
            contracts[_contractId].withdrawn == false,
            "withdrawable: already withdrawn"
        );
        require(
            contracts[_contractId].timelock > block.timestamp,
            "withdrawable: timelock time must be in the future"
        );
        _;
    }
    modifier refundable(bytes32 _contractId) {
        require(
            contracts[_contractId].sender == msg.sender,
            "refundable: not sender"
        );
        require(
            contracts[_contractId].refunded == false,
            "refundable: already refunded"
        );
        require(
            contracts[_contractId].withdrawn == false,
            "refundable: already withdrawn"
        );
        require(
            contracts[_contractId].timelock <= block.timestamp,
            "refundable: timelock not yet passed"
        );
        _;
    }

    modifier contractExists(bytes32 _contractId) {
        require(exists(_contractId), "Already exists contract-id");
        _;
    }

    mapping(bytes32 => LockContract) contracts;

    function newDeal(
        address payable _receiver,
        bytes32 _hashlock,
        uint256 _timelock
    )
        external
        payable
        fundsSent
        futureTimelock(_timelock)
        returns (bytes32 contractId)
    {
        contractId = keccak256(
            abi.encodePacked(
                msg.sender,
                _receiver,
                msg.value,
                _hashlock,
                _timelock
            )
        );

        // Reject if a contract already exists with the same parameters. The
        // sender must change one of these parameters to create a new distinct
        // contract.
        if (exists(contractId)) revert("Contract already exists");

        contracts[contractId] = LockContract(
            payable(msg.sender),
            _receiver,
            msg.value,
            _hashlock,
            _timelock,
            false,
            false,
            0x00
        );

        emit LogHTLCNew(
            contractId,
            msg.sender,
            _receiver,
            msg.value,
            _hashlock,
            _timelock
        );
    }

    function withdraw(bytes32 _contractId, bytes32 _preimage)
        external
        contractExists(_contractId)
        hashlockMatches(_contractId, _preimage)
        withdrawable(_contractId)
        returns (bool)
    {
        LockContract storage c = contracts[_contractId];
        c.preimage = _preimage;
        c.withdrawn = true;
        c.receiver.transfer(c.amount);
        emit LogHTLCWithdraw(_contractId);
        return true;
    }

    function refund(bytes32 _contractId)
        external
        contractExists(_contractId)
        refundable(_contractId)
        returns (bool)
    {
        LockContract storage c = contracts[_contractId];
        c.sender.transfer(c.amount);
        c.refunded = true;
        emit LogHTLCRefund(_contractId);
        return true;
    }

    function exists(bytes32 _contractId) public view returns (bool exist) {
        exist = (contracts[_contractId].sender != address(0));
    }

    function getContract(bytes32 _contractId)
        public
        view
        returns (
            address sender,
            address receiver,
            uint256 amount,
            bytes32 hashlock,
            uint256 timelock,
            bool withdrawn,
            bool refunded,
            bytes32 preimage
        )
    {
        if (exists(_contractId) == false)
            return (address(0), address(0), 0, 0, 0, false, false, 0);
        LockContract storage c = contracts[_contractId];
        return (
            c.sender,
            c.receiver,
            c.amount,
            c.hashlock,
            c.timelock,
            c.withdrawn,
            c.refunded,
            c.preimage
        );
    }

    function func(bytes32 _x) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_x));
    }

    // function getDeal(bytes32 _contractId)public view returns(){

    // }

    event LogHTLCNew(
        bytes32 indexed contractId,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock
    );

    event LogHTLCWithdraw(bytes32 indexed contractId);
    event LogHTLCRefund(bytes32 indexed contractId);
}
