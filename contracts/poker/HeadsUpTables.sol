pragma solidity ^0.5.0;

import {HighCardGameState} from './HighCardGameState.sol';
import {IERC20} from '../token/IERC20.sol';
import {SafeMath} from '../math/SafeMath.sol';

contract HeadsUpTables {
    using SafeMath for uint256;

    // For Domain Separator
    bytes32 constant SALT = 0xf1ae92db93da5bd8411028f6531126984a6eb2e7f66b19e5c22d5a7b0fb00bc7;
    
    // Domain separator completed on contract construction
    bytes32 public DOMAIN_SEPARATOR;
    
    // Dispute types
    uint8 constant public noDispute = 0;
    uint8 constant public unresponsiveDispute = 1;
    uint8 constant public malformedDispute = 2;
    
    // Action types
    uint8 constant public foldAction = 0;
    uint8 constant public callAction = 1;
    uint8 constant public raiseAction = 2;
    uint8 constant public revealAction = 3;
    uint8 constant public commitAction = 4;
    
    // Structs
    struct State {
        uint256[2] currentBalances;
        bytes encodedState;
    }

    struct Claim {
        uint8 disputeType;
        bytes disputeData;
        address proposer;
        uint256 redeemTime;
    }
    
    struct Table {
        bytes32 tableID; // Deterministic ID for any 2 players (same 2 addresses can only play one table at a time)
        bytes32 sessionID; // Uniqueness in case same addresses play multiple times
        address[2] participants;
        uint256 buyIn;
        uint256 smallBlind;
        uint256 tableExpiration;
        uint256 joinExpiration;
        State state;
        Claim claim;
        bool inClaim;
        bool isJoined;
        uint256 disputeDuration;    
    }
    
    HighCardGameState poker;
    mapping (bytes32 => Table) tables;
    mapping (bytes32 => bool) public activeTable;
    bytes32[] public activeTables;
    IERC20 public token;

    /// PUBLIC STATE MODIFYING FUNCTIONS
    constructor (address _pokerGameAddress, address _tokenAddress) public {
        DOMAIN_SEPARATOR = keccak256(abi.encode(address(this), SALT));
        poker = HighCardGameState(_pokerGameAddress);
        token = IERC20(_tokenAddress);
    }
    
    function openTable(address[2] memory participants, bytes memory openData, uint8[2] memory vs, bytes32[2] memory rs, bytes32[2] memory ss, bytes32 uniqueSessionID) public {
        require(participants[0] == msg.sender || participants[1] == msg.sender);
        bytes32 tableID = getTableID(participants[0], participants[1]);
        bytes32 hash = getTableTransactionHash(tableID, uniqueSessionID, openData);
        require(ecrecover(hash, vs[0], rs[0], ss[0]) == participants[0]);
        require(ecrecover(hash, vs[1], rs[1], ss[1]) == participants[1]);
        require(tables[tableID].tableID != tableID);
        require(!activeTable[tableID]);
        (uint256 buyIn, uint256 tableDuration, uint256 joinDuration, uint256 disputeDuration) = abi.decode(openData, (uint256, uint256, uint256, uint256));
        // Optional (but recommended): require duration minimums
        //require(tableDuration >= 600 && disputeDuration >= 600)
        require(buyIn%100==0);
        require(token.transferFrom(msg.sender, address(this), buyIn));
        require(joinDuration<tableDuration);
        tables[tableID].tableExpiration = tableDuration.add(now);
        tables[tableID].joinExpiration = joinDuration.add(now);
        tables[tableID].disputeDuration = disputeDuration;
        tables[tableID].tableID = tableID;
        tables[tableID].sessionID = uniqueSessionID;
        tables[tableID].participants[0] = participants[0];
        tables[tableID].participants[1] = participants[1];
        tables[tableID].buyIn = buyIn;
        tables[tableID].smallBlind = buyIn.div(100);
        require(tables[tableID].smallBlind>0);
        if (participants[0] == msg.sender) {
            tables[tableID].state.currentBalances[0] = buyIn;
        } else {
            tables[tableID].state.currentBalances[1] = buyIn;
        }
        activeTable[tableID] = true;
        activeTables.push(tableID); 
    }
    
    function joinTable(address[2] memory participants) public {
        bytes32 tableID = getTableID(participants[0], participants[1]);
        require(activeTable[tableID]);
        require(tables[tableID].tableID == tableID);
        require(!tables[tableID].isJoined);
        require(now < tables[tableID].joinExpiration);
        require(token.transferFrom(msg.sender, address(this), tables[tableID].buyIn));
        require(tables[tableID].participants[0] == msg.sender || tables[tableID].participants[1] == msg.sender);
        if (tables[tableID].participants[0] == msg.sender) {
            require(tables[tableID].state.currentBalances[0] == 0);
            tables[tableID].state.currentBalances[0] = tables[tableID].buyIn;
        } else {
            require(tables[tableID].state.currentBalances[1] == 0);
            tables[tableID].state.currentBalances[1] = tables[tableID].buyIn;            
        }
        tables[tableID].state.encodedState = poker.initialEncodedState(tables[tableID].smallBlind);
        tables[tableID].isJoined = true;
    }
    
    function proposeClaim(bytes32 tableID, bytes memory ClaimData, uint8 v, bytes32 r, bytes32 s) public {
        require(activeTable[tableID]);
        require(tables[tableID].isJoined);
        if (!tables[tableID].inClaim) {
            // Must propose a Claim before table expires if no settlment already exists.
            require(now < tables[tableID].tableExpiration);
        } else {
            // If Claim already exists can propose a challenge up until the end of existing Claim dispute period.
            require(now < tables[tableID].claim.redeemTime);
        }
        
        // Verify and unpack Claim data
        (bytes memory finalStateData, address proposer, uint8 disputeType, bytes memory disputeData) = verifyUnpackClaimData(tableID, ClaimData, v, r, s);
        
        // Verify and unpack final state data
        bytes memory encodedNewState = verifySignedStateData(tableID, finalStateData);
        
        // Handle Claim
        handleClaim(tableID, encodedNewState, proposer, disputeType, disputeData);
    }
    
    function claimExpiredTable(bytes32 tableID) public {
        require(activeTable[tableID]);
        require(!tables[tableID].inClaim);
        if (tables[tableID].isJoined) {
            if (now > tables[tableID].tableExpiration) {
                closeTable(tableID);
            }
        } else {
            if (now > tables[tableID].joinExpiration) {
                closeTable(tableID);
            }
        }
    }
    
    function claimExpiredClaim(bytes32 tableID) public {
        require(activeTable[tableID]);
        require(tables[tableID].inClaim);
        require(now > tables[tableID].claim.redeemTime);
        require(tables[tableID].claim.proposer == tables[tableID].participants[0] || tables[tableID].claim.proposer == tables[tableID].participants[1]);
        if (tables[tableID].claim.proposer == tables[tableID].participants[0]) {
            tables[tableID].state.currentBalances[0] = tables[tableID].state.currentBalances[0].add(poker.getPot(tables[tableID].state.encodedState));
        } else {
            tables[tableID].state.currentBalances[1] = tables[tableID].state.currentBalances[1].add(poker.getPot(tables[tableID].state.encodedState));
        }
        closeTable(tableID);
    }
    
    /// INTERNAL (PROTECTED) STATE MODIFYING FUNCTIONS
    function advanceToVerifiedState(bytes32 tableID, bytes memory encodedState) internal {
        tables[tableID].state.encodedState = encodedState;
        tables[tableID].state.currentBalances = poker.getBalances(encodedState);
    }
    
    function handleClaim(bytes32 tableID, bytes memory encodedNewState, address proposer, uint8 disputeType, bytes memory disputeData) internal {
        require(poker.isValidStateFastForward(tables[tableID].state.encodedState, encodedNewState, tables[tableID].participants, tables[tableID].smallBlind));
        advanceToVerifiedState(tableID, encodedNewState);
        if (disputeType==noDispute && poker.getActionType(tables[tableID].state.encodedState)!=commitAction) {
            require(false);
        } else if (disputeType==noDispute && poker.getActionType(tables[tableID].state.encodedState)==commitAction && (tables[tableID].state.currentBalances[0]==0 || tables[tableID].state.currentBalances[1]==0)) {
            closeTable(tableID);
        } else if (disputeType==noDispute || (disputeType == unresponsiveDispute && verifyUnresponsiveDispute(tableID, disputeData, proposer))) { 
            tables[tableID].inClaim = true;
            uint256 redeemTime = tables[tableID].disputeDuration.add(now);
            tables[tableID].claim = Claim({proposer: proposer, disputeType: disputeType, disputeData: disputeData, redeemTime: redeemTime});              
        } else if (disputeType==malformedDispute && verifyMalformedDispute(tableID, disputeData, proposer)) {
            if (proposer == tables[tableID].participants[0]) {
                tables[tableID].state.currentBalances[0] = tables[tableID].state.currentBalances[0].add(poker.getPot(tables[tableID].state.encodedState));
            } else if (proposer == tables[tableID].participants[1]) {
                tables[tableID].state.currentBalances[1] = tables[tableID].state.currentBalances[1].add(poker.getPot(tables[tableID].state.encodedState));
            } else {
                require(false);
            }
            closeTable(tableID);
        } else {
            require(false);
        }
    }
    
    function closeTable(bytes32 tableID) internal {
        uint256 amount1 = tables[tableID].state.currentBalances[0];
        uint256 amount2 = tables[tableID].state.currentBalances[1];
        address p1 = tables[tableID].participants[0];
        address p2 = tables[tableID].participants[1];
        if (tables[tableID].isJoined) {
            require(amount1.add(amount2) == tables[tableID].buyIn.mul(2));
        } else {
            require(amount1.add(amount2) == tables[tableID].buyIn);
        }
        delete tables[tableID];
        delete activeTable[tableID];
        for (uint256 i=0; i<activeTables.length; i++) {
            if (activeTables[i] == tableID) {
                activeTables[i] = activeTables[activeTables.length-1];
                delete activeTables[activeTables.length-1];
                activeTables.length--;
            }
        }
        require(token.transfer(p1, amount1));
        require(token.transfer(p2, amount2));
    }
    
    /// PUBLIC VIEW/PURE FUNCTIONS
    function getTableID(address participant1, address participant2) public view returns (bytes32) {
        require(participant1<participant2);
        return keccak256(abi.encodePacked(DOMAIN_SEPARATOR, participant1, participant2));
    }
    
    function getTableTransactionHash(bytes32 tableID, bytes32 sessionID, bytes memory txData) public pure returns (bytes32) {
        return prefixedHash(tableID, sessionID, keccak256(txData));
    }
    
    function getTableOverview(bytes32 tableID) public view returns (address[2] memory, uint256[4] memory, bool[2] memory) {
        require(activeTable[tableID]);
        uint256[4] memory nums;
        nums[0] = tables[tableID].buyIn;
        nums[1] = tables[tableID].tableExpiration;
        nums[2] = tables[tableID].joinExpiration;
        nums[3] = tables[tableID].disputeDuration;
        bool[2] memory bools;
        bools[0] = tables[tableID].isJoined;
        bools[1] = tables[tableID].inClaim;
        return (tables[tableID].participants, nums, bools);
    }
    
    function getTableClaim(bytes32 tableID) public view returns (uint8, address, uint256, bytes memory) {
        require(activeTable[tableID]);
        require(tables[tableID].inClaim);
        return (tables[tableID].claim.disputeType, tables[tableID].claim.proposer, tables[tableID].claim.redeemTime, tables[tableID].claim.disputeData);
    }
    
    function getTableState(bytes32 tableID) public view returns (bytes memory) {
        require(activeTable[tableID]);
        return tables[tableID].state.encodedState;
    }
    
    function verifySignedStateData(bytes32 tableID, bytes memory stateData) public view returns (bytes memory) {
        (bytes memory encodedState, uint8[2] memory vs, bytes32[2] memory rs, bytes32[2] memory ss) = abi.decode(stateData, (bytes, uint8[2], bytes32[2], bytes32[2]));
        bytes32 hash = getOpenTableTransactionHash(tableID, encodedState);
        require(ecrecover(hash, vs[0], rs[0], ss[0]) == tables[tableID].participants[0]);
        require(ecrecover(hash, vs[1], rs[1], ss[1]) == tables[tableID].participants[1]);
        
        return encodedState;
    }
    
    function verifyHalfSignedStateData(bytes32 tableID, bytes memory stateData, address signer) public view returns (bytes memory) {
        (bytes memory encodedState, uint8 v, bytes32 r, bytes32 s) = abi.decode(stateData, (bytes, uint8, bytes32, bytes32));
        bytes32 hash = getOpenTableTransactionHash(tableID, encodedState);
        require(ecrecover(hash, v, r, s) == signer);
        return encodedState;
    }
    
    function verifyUnpackClaimData(bytes32 tableID, bytes memory ClaimData, uint8 v, bytes32 r, bytes32 s) public view returns (bytes memory, address, uint8, bytes memory) {
        (bytes memory finalStateData, address proposer, uint8 disputeType, bytes memory disputeData) = abi.decode(ClaimData, (bytes, address, uint8, bytes));
        require(proposer==tables[tableID].participants[0] || proposer==tables[tableID].participants[1]);
        bytes32 hash = getOpenTableTransactionHash(tableID, ClaimData);
        require(ecrecover(hash, v, r, s)==proposer);
        
        return (finalStateData, proposer, disputeType, disputeData);
    }

    function verifyUnresponsiveDispute(bytes32 tableID, bytes memory disputeData, address proposer) public view returns (bool) {
        bytes memory encodedNewState = verifyHalfSignedStateData(tableID, disputeData, proposer);
        return poker.isValidStateTransition(tables[tableID].state.encodedState, encodedNewState, tables[tableID].participants, tables[tableID].smallBlind);
    }
    
    function verifyMalformedDispute(bytes32 tableID, bytes memory disputeData, address proposer) public view returns (bool) {
        address signer = tables[tableID].participants[0];
        if (proposer == tables[tableID].participants[0]) {
            signer = tables[tableID].participants[1];
        }
        bytes memory encodedNewState = verifyHalfSignedStateData(tableID, disputeData, signer);
        return !poker.isValidStateTransition(tables[tableID].state.encodedState, encodedNewState, tables[tableID].participants, tables[tableID].smallBlind);
    }
    
    /// INTERNAL VIEW/PURE FUNCTIONS
    function getOpenTableTransactionHash(bytes32 tableID, bytes memory txData) internal view returns (bytes32) {
        return prefixedHash(tableID, tables[tableID].sessionID, keccak256(txData));
    }
    function prefixedHash(bytes32 tableID, bytes32 sessionID, bytes32 txHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", tableID, sessionID, txHash));
    }
}