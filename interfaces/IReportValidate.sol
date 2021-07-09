pragma solidity 0.6.12;

interface IReportValidate {
    function validateReport(bytes calldata _report) external view returns (bool, bytes memory);
}
