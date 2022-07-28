// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract TimeLock {

    address public owner;
    uint256 public constant MIN_DELAY = 10;     // 10 sec
    uint256 public constant MAX_DELAY = 1000;   //1000 sec
    uint56 public constant GRACE_PERIOD = 1000; //1000sec

    mapping(bytes32 => bool) public queued;

    event queuedTx(
        address indexed target,
        uint256 indexed value,
        string  func,
        bytes  data,
        uint256 timestamp,
        bytes32 indexed txId
    );

    event executedTx(
        address indexed target,
        uint256 indexed value,
        string  func,
        bytes  data,
        uint256 timestamp,
        bytes32 indexed txId
    );

    event cancelledTX(bytes32 indexed txId);

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner Can");
        _;
    }

    function getTxId (
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) public pure returns (bytes32 txId){
       return keccak256(
        abi.encode(
            _target, _value, _func, _data, _timestamp
        )
       );
    }

    
    function queue (
        address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp
    ) external onlyOwner {
        // create tx id
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        // check tx id unique 
        require(queued[txId] == false, "Tx id is queued");

        // check timestamp
        // ---|------------------|----------------|-------
        //  block           block + min      block + max  

        require(
            (_timestamp > block.timestamp + MIN_DELAY) ||
            (_timestamp < block.timestamp + MAX_DELAY)
        , "TimeStamp is not in the Range");
        
        // queue tx
        queued[txId] = true;

        emit queuedTx(
            _target, _value, _func, _data, _timestamp, txId
        );
    }


    function execute(
       address _target,
        uint256 _value,
        string calldata _func,
        bytes calldata _data,
        uint256 _timestamp 
    ) external payable  onlyOwner returns (bytes memory) {
        bytes32 txId = getTxId(_target, _value, _func, _data, _timestamp);

        // check the tx queued 
        require(queued[txId] == true, "Tx is queued");

        // check block.timestamp > _timestamp
        require(block.timestamp > _timestamp , "TimeStamp is not in the range");

        // check timestamp
        // ----------|------------------|-------------
        //        timestamp    timestamp + grace period    
        require(block.timestamp < _timestamp + GRACE_PERIOD, "Tx is expired");

        // remove tx from queue
        queued[txId] = false;

        bytes memory data;
        if(bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))), _data
            );
        } else {
            data =_data;
        }
        
        // execute the tx
        (bool done, bytes memory response) = _target.call{value: _value}(data);
        require(done == true, "Tx Failed");

        emit executedTx(
            _target, _value, _func, _data, _timestamp, txId
        );
    
        return response;
    }

    function cancelTx(bytes32 _txId) external onlyOwner {
        require(queued[_txId] != false, "Tx is not queued");
        queued[_txId] = false;
        emit cancelledTX(_txId);
    }
}