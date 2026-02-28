// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;
contract note {
    string myNote;
    function setNote(string memory _note) public {
        myNote = _note;
    }
    function getNote() public view returns (string memory) {
        return myNote;
    }
    function pureNote(string memory _pureNote) public pure returns (string memory) {
        return _pureNote;
    }
}