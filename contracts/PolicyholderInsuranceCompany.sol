// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Smart Contract automatically generated from a BPMN diagram
 * @dev Timer events handled using block numbers.
 */
contract PolicyholderInsuranceCompany is ReentrancyGuard, Ownable, Pausable {

    enum State { DISABLED, ENABLED, DONE }

    mapping(string => State) public elementStates;
    mapping(string => uint256) public blockLimits;
    mapping(string => address) public participantAddresses;

    struct AuditLog {
        string taskId;
        address user;
        uint256 timestamp;
    }

    AuditLog[] public auditLogs;
    event TaskCompleted(string taskId);

    event TimerScheduled(string timerId, uint256 deadlineBlock);

    struct GatewayData {
        string participantName;
        string[] dependencies;
        string yesTargetId;
        string noTargetId;
    }

    mapping(string => GatewayData) public gatewayMap;

    constructor() Ownable(msg.sender) Pausable() {
        participantAddresses["Policyholder"] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        participantAddresses["InsuranceCompany"] = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;

        elementStates["Event_StartPolicyholder"] = State.ENABLED;

        elementStates["Activity_ProvideAdditionalInfo"] = State.DISABLED;
        elementStates["Activity_ReceiveProposal"] = State.DISABLED;
        elementStates["Activity_SubmitRequestPolicy"] = State.DISABLED;
        elementStates["Activity_SendPolicySigned"] = State.DISABLED;
        elementStates["Activity_PrepareNewProposal"] = State.DISABLED;
        elementStates["Activity_RequestMoreInfo"] = State.DISABLED;
        elementStates["Activity_ReceivePolicySigned"] = State.DISABLED;
        elementStates["Activity_PreparePolicyProposal"] = State.DISABLED;
        elementStates["Activity_SendPolicyProposal"] = State.DISABLED;
        elementStates["Activity_ReceiveRequest"] = State.DISABLED;
        elementStates["Gateway_CheckSign"] = State.DISABLED;
        elementStates["Gateway_0qbxamk"] = State.DISABLED;
        elementStates["Event_5DayDeadline"] = State.DISABLED;
        elementStates["Event_7DayDeadline"] = State.DISABLED;

        // [ADDED] Initialize all timer events at contract deployment
        // This means the timers start counting from now (block.number)
        blockLimits["TimerEventDefinition_01t8nhl"] = block.number + 36000;
        elementStates["TimerEventDefinition_01t8nhl"] = State.ENABLED;
        emit TimerScheduled("TimerEventDefinition_01t8nhl", block.number + 36000);
        blockLimits["TimerEventDefinition_7Days"] = block.number + 50400;
        elementStates["TimerEventDefinition_7Days"] = State.ENABLED;
        emit TimerScheduled("TimerEventDefinition_7Days", block.number + 50400);

        {
            string[] memory depArr = new string[](1);
            depArr[0] = "Event_5DayDeadline";
            gatewayMap["Gateway_CheckSign"] = GatewayData({
                participantName: "Policyholder",
                dependencies: depArr,
                yesTargetId: "Activity_SendPolicySigned",
                noTargetId: "Activity_PrepareNewProposal"
            });
        }
        {
            string[] memory depArr = new string[](1);
            depArr[0] = "Activity_ReceiveRequest";
            gatewayMap["Gateway_0qbxamk"] = GatewayData({
                participantName: "InsuranceCompany",
                dependencies: depArr,
                yesTargetId: "Activity_PreparePolicyProposal",
                noTargetId: "Activity_RequestMoreInfo"
            });
        }
    }

    function updateParticipantAddress(string memory participant, address newAddress) public onlyOwner {
        require(newAddress != address(0), "Invalid address");
        participantAddresses[participant] = newAddress;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function resetElementState(string memory elementId) public onlyOwner {
        elementStates[elementId] = State.DISABLED;
    }

    function logAudit(string memory taskId) private {
        auditLogs.push(AuditLog({taskId: taskId, user: msg.sender, timestamp: block.timestamp}));
    }

    function startEvent() public nonReentrant whenNotPaused {
        require(elementStates["Event_StartPolicyholder"] == State.ENABLED, "StartEvent not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");

        elementStates["Event_StartPolicyholder"] = State.DONE;
        logAudit("Event_StartPolicyholder");
        emit TaskCompleted("Event_StartPolicyholder");

        elementStates["Activity_SubmitRequestPolicy"] = State.ENABLED;
    }

    function provideAdditionalInfo() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ProvideAdditionalInfo"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");


        elementStates["Activity_ProvideAdditionalInfo"] = State.DONE;
        logAudit("Activity_ProvideAdditionalInfo");
        emit TaskCompleted("Activity_ProvideAdditionalInfo");

        elementStates["Activity_ReceiveRequest"] = State.ENABLED;
    }

    function receiveProposal() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ReceiveProposal"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");


        elementStates["Activity_ReceiveProposal"] = State.DONE;
        logAudit("Activity_ReceiveProposal");
        emit TaskCompleted("Activity_ReceiveProposal");

        elementStates["Event_5DayDeadline"] = State.ENABLED;
    }

    function submitInsurancePolicyRequest() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SubmitRequestPolicy"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");

        require(elementStates["Event_StartPolicyholder"] == State.DONE, "Dependency not completed");

        elementStates["Activity_SubmitRequestPolicy"] = State.DONE;
        logAudit("Activity_SubmitRequestPolicy");
        emit TaskCompleted("Activity_SubmitRequestPolicy");

        elementStates["Activity_ReceiveRequest"] = State.ENABLED;
    }

    function sendPolicySigned() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SendPolicySigned"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");

        require(elementStates["Gateway_CheckSign"] == State.DONE, "Dependency not completed");

        elementStates["Activity_SendPolicySigned"] = State.DONE;
        logAudit("Activity_SendPolicySigned");
        emit TaskCompleted("Activity_SendPolicySigned");

        elementStates["Activity_ReceivePolicySigned"] = State.ENABLED;
    }

    function prepareNewProposal() public nonReentrant whenNotPaused {
        require(elementStates["Activity_PrepareNewProposal"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can do this task");

        require(elementStates["Gateway_CheckSign"] == State.DONE, "Dependency not completed");

        elementStates["Activity_PrepareNewProposal"] = State.DONE;
        logAudit("Activity_PrepareNewProposal");
        emit TaskCompleted("Activity_PrepareNewProposal");

        elementStates["Activity_PreparePolicyProposal"] = State.ENABLED;
    }

    function requestMoreInfo() public nonReentrant whenNotPaused {
        require(elementStates["Activity_RequestMoreInfo"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can do this task");

        require(elementStates["Gateway_0qbxamk"] == State.DONE, "Dependency not completed");

        elementStates["Activity_RequestMoreInfo"] = State.DONE;
        logAudit("Activity_RequestMoreInfo");
        emit TaskCompleted("Activity_RequestMoreInfo");

        elementStates["Activity_ProvideAdditionalInfo"] = State.ENABLED;
    }

    function receivePolicySigned() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ReceivePolicySigned"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can do this task");


        elementStates["Activity_ReceivePolicySigned"] = State.DONE;
        logAudit("Activity_ReceivePolicySigned");
        emit TaskCompleted("Activity_ReceivePolicySigned");

        elementStates["Event_1y29p4i"] = State.ENABLED;
    }

    function preparePolicyProposal() public nonReentrant whenNotPaused {
        require(elementStates["Activity_PreparePolicyProposal"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can do this task");

        require(elementStates["Gateway_0qbxamk"] == State.DONE, "Dependency not completed");

        elementStates["Activity_PreparePolicyProposal"] = State.DONE;
        logAudit("Activity_PreparePolicyProposal");
        emit TaskCompleted("Activity_PreparePolicyProposal");

        elementStates["Event_7DayDeadline"] = State.ENABLED;
    }

    function sendPolicyProposal() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SendPolicyProposal"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can do this task");

        require(elementStates["Event_7DayDeadline"] == State.DONE, "Dependency not completed");

        elementStates["Activity_SendPolicyProposal"] = State.DONE;
        logAudit("Activity_SendPolicyProposal");
        emit TaskCompleted("Activity_SendPolicyProposal");

        elementStates["Activity_ReceiveProposal"] = State.ENABLED;
    }

    function receiveRequest() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ReceiveRequest"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can do this task");


        elementStates["Activity_ReceiveRequest"] = State.DONE;
        logAudit("Activity_ReceiveRequest");
        emit TaskCompleted("Activity_ReceiveRequest");

        elementStates["Gateway_0qbxamk"] = State.ENABLED;
    }

    function f5DaysSignDeadline() public nonReentrant whenNotPaused {
        require(elementStates["Event_5DayDeadline"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Policyholder"], "Only Policyholder can trigger this event");

        require(elementStates["Activity_ReceiveProposal"] == State.DONE, "Dependency not completed");

        elementStates["Event_5DayDeadline"] = State.DONE;
        logAudit("Event_5DayDeadline");
        emit TaskCompleted("Event_5DayDeadline");

        elementStates["Gateway_CheckSign"] = State.ENABLED;
    }

    function f7DaysProposalDeadline() public nonReentrant whenNotPaused {
        require(elementStates["Event_7DayDeadline"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["InsuranceCompany"], "Only InsuranceCompany can trigger this event");

        require(elementStates["Activity_PreparePolicyProposal"] == State.DONE, "Dependency not completed");

        elementStates["Event_7DayDeadline"] = State.DONE;
        logAudit("Event_7DayDeadline");
        emit TaskCompleted("Event_7DayDeadline");

        elementStates["Activity_SendPolicyProposal"] = State.ENABLED;
    }

    function triggerTimereventdefinition01t8nhl() public nonReentrant whenNotPaused {
        require(elementStates["TimerEventDefinition_01t8nhl"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerEventDefinition_01t8nhl"], "Timer not expired yet");
        elementStates["TimerEventDefinition_01t8nhl"] = State.DONE;
        logAudit("TimerEventDefinition_01t8nhl");
        emit TaskCompleted("TimerEventDefinition_01t8nhl");

    }

    function triggerTimereventdefinition7days() public nonReentrant whenNotPaused {
        require(elementStates["TimerEventDefinition_7Days"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerEventDefinition_7Days"], "Timer not expired yet");
        elementStates["TimerEventDefinition_7Days"] = State.DONE;
        logAudit("TimerEventDefinition_7Days");
        emit TaskCompleted("TimerEventDefinition_7Days");

    }

    function gatewayAction(string memory gatewayId, bool condition) public nonReentrant whenNotPaused {
        GatewayData memory gdata = gatewayMap[gatewayId];

        require(elementStates[gatewayId] == State.ENABLED, "Gateway not enabled");
        require(msg.sender == participantAddresses[gdata.participantName], "Only correct participant can call");

        // Dependencies must be DONE
        for (uint i = 0; i < gdata.dependencies.length; i++) {
            require(elementStates[gdata.dependencies[i]] == State.DONE, "Dependency not completed");
        }

        elementStates[gatewayId] = State.DONE;
        logAudit(gatewayId);
        emit TaskCompleted(gatewayId);

        if (condition) {
            if (bytes(gdata.yesTargetId).length > 0) {
                elementStates[gdata.yesTargetId] = State.ENABLED;
            }
        } else {
            if (bytes(gdata.noTargetId).length > 0) {
                elementStates[gdata.noTargetId] = State.ENABLED;
            }
        }
    }

}
