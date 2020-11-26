pragma solidity ^0.5.0;

import {MentalPoker} from './MentalPoker.sol';
import {SafeMath} from '../math/SafeMath.sol';

contract HighCardGameState {
    using SafeMath for uint256;

    // Action types
    uint8 constant public foldAction = 0;
    uint8 constant public callAction = 1;
    uint8 constant public raiseAction = 2;
    uint8 constant public revealAction = 3;
    uint8 constant public commitAction = 4;
    
    MentalPoker mp;
    struct State {
        uint256 handNumber;
        uint8 handRound;
        address handWinner;
        address lastActor;
        uint8 lastActionType;
        uint256[2] currentBalances;
        uint256 pot;
        uint256 toCall;
        uint256[2] cardX;
        uint256[2] cardY;
        uint256[4] keys;
    }
    
    constructor (address mentalPokerAddress) public {
        mp = MentalPoker(mentalPokerAddress);
    }
    
    function isValidStateTransition(bytes memory encodedPreviousState, bytes memory encodedNewState, address[2] memory participants, uint256 smallBlind) public view returns (bool) {
        State memory newState = decodeState(encodedNewState);
        State memory oldState = decodeState(encodedPreviousState);
        uint8 actorIndex;
        if (newState.lastActor == participants[0]) {
            actorIndex = 0;
        } else if (newState.lastActor == participants[1]) {
            actorIndex = 1;
        } else {
            return false;
        }
        if (newState.currentBalances[0].add(newState.currentBalances[1]).add(newState.pot) != smallBlind.mul(200)) {
            return false;
        }
        bool isEvenHand = newState.handNumber%2==0;
        bool isEvenRound = newState.handRound%2==0;
        if (actorIndex==1 && isEvenHand == isEvenRound) {
            return false;
        } else if (actorIndex==0 && isEvenHand != isEvenRound) {
            return false;
        }
        if (newState.handNumber==oldState.handNumber && newState.handRound==oldState.handRound+1) {
            if (newState.cardX[0] != oldState.cardX[0] || newState.cardX[1] != oldState.cardX[1] || newState.cardY[0] != oldState.cardY[0] || newState.cardY[1] != oldState.cardY[1]) {
                return false;
            }
            if (newState.currentBalances[(actorIndex+1)%2] != oldState.currentBalances[(actorIndex+1)%2]) {
                return false;
            }
            if (newState.keys[1]!=oldState.keys[1] || newState.keys[2]!=oldState.keys[2]) {
                return false;
            } 
            if (newState.lastActionType != revealAction) {
                if (newState.keys[0]!=oldState.keys[0] || newState.keys[3]!=oldState.keys[3]) {
                    return false;
                }    
            } else {
                if (actorIndex == 0) {
                    if (newState.keys[3] != oldState.keys[3] || oldState.keys[0] == newState.keys[0] || oldState.keys[0] != 0) {
                        return false;
                    }
                    if (oldState.lastActionType == revealAction && newState.keys[3] == 0) {
                        return false;
                    }
                } else {
                    if (newState.keys[0] != oldState.keys[0] || oldState.keys[3] == newState.keys[3] || oldState.keys[3] != 0) {
                        return false;
                    }
                    if (oldState.lastActionType == revealAction && newState.keys[0] == 0) {
                        return false;
                    }
                }
            }
            if (newState.lastActionType == callAction) {
                if (newState.toCall != 0 || oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex]) != oldState.toCall) {
                    return false;
                }
                if (newState.pot != oldState.pot.add(oldState.toCall)) {
                    return false;
                }
            } else if (newState.lastActionType == raiseAction) {
                if (newState.toCall == 0 || oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex]) != newState.toCall.add(oldState.toCall)) {
                    return false;
                }
                if (newState.pot != newState.toCall.add(oldState.toCall).add(oldState.pot)) {
                    return false;
                }
            } else if (newState.lastActionType == commitAction) {
                uint8 winnerIndex;
                if (newState.handWinner == participants[0]) {
                    winnerIndex = 0;
                } else if (newState.handWinner == participants[1]) {
                    winnerIndex = 1;
                } else {
                    return false;
                }
                if (oldState.lastActionType == foldAction) {
                    if (actorIndex != winnerIndex || oldState.pot != newState.currentBalances[actorIndex].sub(oldState.currentBalances[actorIndex])) {
                        return false;
                    } 
                }
                if (oldState.lastActionType == revealAction) {
                    if (oldState.pot != newState.currentBalances[winnerIndex].sub(oldState.currentBalances[winnerIndex])) {
                        return false;
                    }
                    uint256[2] memory keysP1 = [newState.keys[0], newState.keys[1]];
                    uint256[2] memory keysP2 = [newState.keys[2], newState.keys[3]];
                    if (!isValidHandResult(newState.cardX, newState.cardY, keysP1, keysP2, winnerIndex)) {
                        return false;
                    }
                }
            } else if (newState.lastActionType == foldAction) {
                if (newState.toCall != 0 || newState.pot != oldState.pot || oldState.currentBalances[actorIndex]!=newState.currentBalances[actorIndex]) {
                    return false;
                }
            } else if (newState.lastActionType == revealAction) {
                if (oldState.lastActionType != revealAction && oldState.lastActionType != callAction) {
                    return false;
                }
                if (oldState.toCall != 0 || newState.pot != oldState.pot || oldState.currentBalances[actorIndex]!=newState.currentBalances[actorIndex]) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (newState.handNumber==oldState.handNumber.add(1) && newState.handRound==1 && oldState.lastActionType==commitAction) {
            if (oldState.currentBalances[(actorIndex+1)%2].sub(newState.currentBalances[(actorIndex+1)%2]) != smallBlind.mul(2)) {
                return false;
            }
            if (newState.lastActionType == callAction) {
                if (newState.pot != smallBlind.mul(4) || newState.toCall != 0) {
                    return false;
                }
                if (oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex]) != smallBlind.mul(2)) {
                    return false;
                }
            } else if (newState.lastActionType == raiseAction) {
                if (newState.pot != oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex].add(smallBlind.mul(2)))) {
                    return false;
                }
                if (newState.toCall != oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex].add(smallBlind.mul(2)))) {
                    return false;
                }
            } else if (newState.lastActionType == foldAction) {
                if (newState.pot != smallBlind.mul(3) || newState.toCall != 0) {
                    return false;
                }
                if (oldState.currentBalances[actorIndex].sub(newState.currentBalances[actorIndex]) != smallBlind) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
        
        return true;
    }
    
    function isValidStateFastForward(bytes memory encodedPreviousState, bytes memory encodedNewState, address[2] memory participants, uint256 smallBlind) public view returns (bool) {
        State memory newState = decodeState(encodedNewState);
        State memory oldState = decodeState(encodedPreviousState);
        if (newState.handNumber==oldState.handNumber && newState.handRound==oldState.handRound+1) {
            return isValidStateTransition(encodedPreviousState, encodedNewState, participants, smallBlind);
        } else if (newState.handNumber==oldState.handNumber.add(1) && newState.handRound==1 && oldState.lastActionType==commitAction) {
            return isValidStateTransition(encodedPreviousState, encodedNewState, participants, smallBlind);
        }
        if (newState.handNumber<oldState.handNumber || (newState.handNumber==oldState.handNumber && newState.handRound<=oldState.handRound)) {
            return false;
        }
        if (newState.currentBalances[0].add(newState.currentBalances[1]).add(newState.pot) != smallBlind.mul(200)) {
            return false;
        }
        if (newState.cardX[0]==0 || newState.cardY[0]==0 || newState.cardX[1]==0 || newState.cardY[1]==0 || newState.keys[1]==0 || newState.keys[2]==0) {
            return false;
        }
        bool isEvenHand = newState.handNumber%2==0;
        bool isEvenRound = newState.handRound%2==0;
        if (newState.lastActor != participants[0] && newState.lastActor != participants[1]) {
            return false;
        } else if (newState.lastActor == participants[1] && isEvenHand == isEvenRound) {
            return false;
        } else if (newState.lastActor == participants[0] && isEvenHand != isEvenRound) {
            return false;
        }
        if (newState.lastActionType==commitAction) {
            if (newState.toCall != 0 || newState.pot != 0) {
                return false;
            }
            if (newState.handWinner != participants[0] && newState.handWinner != participants[1]) {
                return false;
            }
        }
        if (newState.lastActionType==callAction && newState.toCall != 0) {
            return false;
        }
        if (newState.lastActionType==foldAction && newState.toCall != 0) {
            return false;
        }
        if (newState.lastActionType==revealAction) {
            if (newState.toCall != 0) {
                return false;
            }
            if (newState.lastActor == participants[0] && newState.keys[0]==0) {
                return false;
            }
            if (newState.lastActor == participants[1] && newState.keys[3]==0) {
                return false;
            }
        }
        if (newState.lastActionType==raiseAction && newState.toCall == 0) {
            return false;
        }
        
        return true;
    }
    
    function isValidHandResult(uint256[2] memory cardX, uint256[2] memory cardY, uint256[2] memory keysP1, uint256[2] memory keysP2, uint8 winnerIndex) public view returns (bool) {
        (string memory card0, bool ok0) = mp.revealCard(cardX[0], cardY[0], keysP1[0], keysP2[0]);
        if (!ok0) {
            return false;
        }
        (string memory card1, bool ok1) = mp.revealCard(cardX[1], cardY[1], keysP1[1], keysP2[1]);
        if (!ok1) {
            return false;
        }
        (string memory winCard, bool ok) = mp.highCard(card0, card1);
        if (!ok) {
            return false;
        }
        if (mp.cardEqual(card0, winCard) && winnerIndex==1) {
            return false;
        }
        if (mp.cardEqual(card1, winCard) && winnerIndex==0) {
            return false;
        }
        return true;
    }
    
    function getPot(bytes memory encodedState) public pure returns (uint256) {
        (uint256 handNumber, uint8[2] memory roundAction, uint256[4] memory values, uint256[8] memory cardsAndKeys, address[2] memory actorWinner) = abi.decode(encodedState, (uint256, uint8[2], uint256[4], uint256[8], address[2]));
        return values[2];
    }
    
    function getBalances(bytes memory encodedState) public pure returns (uint256[2] memory) {
        (uint256 handNumber, uint8[2] memory roundAction, uint256[4] memory values, uint256[8] memory cardsAndKeys, address[2] memory actorWinner) = abi.decode(encodedState, (uint256, uint8[2], uint256[4], uint256[8], address[2]));
        return [values[0], values[1]];
    }
    
    function getActionType(bytes memory encodedState) public pure returns (uint8) {
        (uint256 handNumber, uint8[2] memory roundAction, uint256[4] memory values, uint256[8] memory cardsAndKeys, address[2] memory actorWinner) = abi.decode(encodedState, (uint256, uint8[2], uint256[4], uint256[8], address[2]));
        return roundAction[1];
    }
    
    function initialEncodedState(uint256 smallBlind) public view returns (bytes memory) {
        State memory state;
        state.currentBalances[0] = smallBlind.mul(100);
        state.currentBalances[1] = smallBlind.mul(100);
        return encodeState(state);
    }
    
    function encodeState(State memory state) internal pure returns (bytes memory) {
        uint256[4] memory values;
        uint256[8] memory cardsAndKeys;
        uint8[2] memory roundAction;
        address[2] memory actorWinner;
        roundAction[0] = state.handRound;
        roundAction[1] = state.lastActionType;
        values[0] = state.currentBalances[0];
        values[1] = state.currentBalances[1];
        values[2] = state.pot;
        values[3] = state.toCall;
        cardsAndKeys[0] = state.cardX[0];
        cardsAndKeys[1] = state.cardY[0];
        cardsAndKeys[2] = state.keys[0];
        cardsAndKeys[3] = state.keys[2];
        cardsAndKeys[4] = state.cardX[1];
        cardsAndKeys[5] = state.cardY[1];
        cardsAndKeys[6] = state.keys[1];
        cardsAndKeys[7] = state.keys[3];
        actorWinner[0] = state.lastActor;
        actorWinner[1] = state.handWinner;
        return abi.encode(state.handNumber, roundAction, values, cardsAndKeys, actorWinner);
    }
    
    function decodeState(bytes memory encodedState) internal pure returns (State memory) {
        (uint256 handNumber, uint8[2] memory roundAction, uint256[4] memory values, uint256[8] memory cardsAndKeys, address[2] memory actorWinner) = abi.decode(encodedState, (uint256, uint8[2], uint256[4], uint256[8], address[2]));
        uint256[2] memory cardX = [cardsAndKeys[0], cardsAndKeys[4]];
        uint256[2] memory cardY = [cardsAndKeys[1], cardsAndKeys[5]];
        uint256[4] memory keys =  [cardsAndKeys[2], cardsAndKeys[6], cardsAndKeys[3], cardsAndKeys[7]];
        State memory state;
        state.handNumber = handNumber;
        state.handRound = roundAction[0];
        state.lastActionType = roundAction[1];
        state.lastActor = actorWinner[0];
        state.handWinner = actorWinner[1];
        state.pot = values[2];
        state.toCall = values[3];
        state.currentBalances[0] = values[0];
        state.currentBalances[1] = values[1];
        state.cardX = cardX;
        state.cardY = cardY;
        state.keys = keys;
        
        return state;
    }
}


