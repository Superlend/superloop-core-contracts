// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDistributor {
    struct MerkleTree {
        bytes32 merkleRoot;
        bytes32 ipfsHash;
    }

    function updateTree(MerkleTree calldata _tree) external;

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external;
}
