// SPDX-License-Identifier: MIT
import './IRelayRecipient.sol';

pragma solidity 0.6.12;

// Source:
// https://github.com/opengsn/gsn/blob/995647ebf8e34ac183d5b99c06c385bc1995d6dd/packages/contracts/src/BaseRelayRecipient.sol
// With payable modified reinstated, msgData removed

/**
 * A base contract to be inherited by any contract that want to receive relayed transactions
 * A subclass must use "_msgSender()" instead of "msg.sender"
 */
abstract contract BaseRelayRecipient is IRelayRecipient {

    function isTrustedForwarder(address forwarder) public override pure returns(bool) {
        return forwarder == 0x86C80a8aa58e0A4fa09A69624c31Ab2a6CAD56b8;
    }

    /**
     * return the sender of this call.
     * if the call came through our trusted forwarder, return the original sender.
     * otherwise, return `msg.sender`.
     * should be used in the contract anywhere instead of msg.sender
     */
    function _msgSender() internal override virtual view returns (address payable ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }
}
