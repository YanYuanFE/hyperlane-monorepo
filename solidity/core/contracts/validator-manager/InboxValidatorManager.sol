// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;
pragma abicoder v2;

// ============ Internal Imports ============
import {IInbox} from "../../interfaces/IInbox.sol";
import {SchnorrValidatorManager} from "./SchnorrValidatorManager.sol";
import {BN256} from "../../libs/BN256.sol";
import "hardhat/console.sol";

/**
 * @title InboxValidatorManager
 * @notice Verifies checkpoints are signed by a quorum of validators and submits
 * them to an Inbox.
 */
contract InboxValidatorManager is SchnorrValidatorManager {
    struct Checkpoint {
        bytes32 root;
        uint256 index;
    }

    // ============ Libraries ============

    using BN256 for BN256.G1Point;

    // ============ Events ============

    /**
     * @notice Emitted when a checkpoint has been signed by a quorum
     * of validators and cached on an Inbox.
     * @dev This event allows watchers to observe the signatures they need
     * to prove fraud on the Outbox.
     */
    event Quorum(
        Checkpoint checkpoint,
        uint256[2] sigScalars,
        bytes32 compressedPublicKey,
        bytes32 compressedNonce,
        BN256.G1Point[] omitted
    );

    // ============ Constructor ============

    /**
     * @dev Reverts if `_validators` has any duplicates.
     * @param _remoteDomain The remote domain of the outbox chain.
     * @param _validators The set of validator addresses.
     * @param _threshold The quorum threshold. Must be greater than or equal
     * to the length of `_validators`.
     */
    // solhint-disable-next-line no-empty-blocks
    constructor(
        uint32 _remoteDomain,
        BN256.G1Point[] memory _validators,
        uint256 _threshold
    ) SchnorrValidatorManager(_remoteDomain, _validators, _threshold) {}

    // ============ External Functions ============

    function process(
        IInbox _inbox,
        Checkpoint calldata _checkpoint,
        uint256[2] calldata _sigScalars,
        BN256.G1Point calldata _nonce,
        BN256.G1Point[] calldata _omittedValidatorNegPublicKeys,
        bytes calldata _message,
        bytes32[32] calldata _proof,
        uint256 _leafIndex
    ) external {
        require(
            _omittedValidatorNegPublicKeys.length <= threshold,
            "!threshold"
        );
        bytes32 _compressedKey;
        // Restrict scope to keep stack small enough.
        {
            BN256.G1Point memory _key = verificationKey(
                _omittedValidatorNegPublicKeys
            );
            _compressedKey = _key.compress();
            uint256 _challenge = uint256(
                keccak256(
                    abi.encodePacked(_sigScalars[0], domainHash, _checkpoint.root, _checkpoint.index)
                )
            );
            require(verify(_key, _nonce, _sigScalars[1], _challenge), "!sig");
        }
        // Okay, what if we mapped the compressed key => y value?
        // Then, we could pull the omitted keys from storage...
        /*
        bytes32[] memory _compressedOmitted = new bytes32[](
            _omittedValidatorNegPublicKeys.length
        );
        for (uint256 i = 0; i < _omittedValidatorNegPublicKeys.length; i++) {
            _compressedOmitted[i] = _omittedValidatorNegPublicKeys[i]
                .compress();
        }
        */
        emit Quorum(
            _checkpoint,
            _sigScalars,
            _compressedKey,
            _nonce.compress(),
            _omittedValidatorNegPublicKeys
        );
        _inbox.process(_checkpoint.root, _checkpoint.index, _message, _proof, _leafIndex, "0x00");
    }
}
