pragma solidity ^0.6.12;

import "../interfaces/IReportValidate.sol";

contract ReportValidate is IReportValidate {
    function validateReport(bytes calldata _report)
    external
    view
    override
    returns (bool, bytes memory) {

    }
}
