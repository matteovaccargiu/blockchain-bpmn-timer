// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Smart Contract automatically generated from a BPMN diagram
 * @dev Timer events handled using block numbers.
 */
contract CitizenMunicipality is ReentrancyGuard, Ownable, Pausable {

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
        participantAddresses["Citizen"] = ;
        participantAddresses["Municipality"] = ;

        elementStates["Event_StartCitizen"] = State.ENABLED;

        elementStates["Activity_SendRequestMunicipality"] = State.DISABLED;
        elementStates["Activity_DocumentsReceived"] = State.DISABLED;
        elementStates["Activity_SendFeedback"] = State.DISABLED;
        elementStates["Activity_CompleteRequestAndResend"] = State.DISABLED;
        elementStates["Activity_ElaborateRequest"] = State.DISABLED;
        elementStates["Activity_ReturnRequestToCitizen"] = State.DISABLED;
        elementStates["Activity_SendDocuments"] = State.DISABLED;
        elementStates["Activity_AssignNewOperator"] = State.DISABLED;
        elementStates["Gateway_CheckRequest"] = State.DISABLED;
        elementStates["Gateway_CheckDocuments"] = State.DISABLED;
        elementStates["Event_ReceiveRequest"] = State.DISABLED;
        elementStates["Event_30DayDeadline"] = State.DISABLED;
        elementStates["Event_15DayDeadline"] = State.DISABLED;

        {
            string[] memory depArr = new string[](1);
            depArr[0] = "Event_ReceiveRequest";
            gatewayMap["Gateway_CheckRequest"] = GatewayData({
                participantName: "Municipality",
                dependencies: depArr,
                yesTargetId: "Activity_ElaborateRequest",
                noTargetId: "Activity_ReturnRequestToCitizen"
            });
        }
        {
            string[] memory depArr = new string[](1);
            depArr[0] = "Event_30DayDeadline";
            gatewayMap["Gateway_CheckDocuments"] = GatewayData({
                participantName: "Municipality",
                dependencies: depArr,
                yesTargetId: "Activity_SendDocuments",
                noTargetId: ""
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
        require(elementStates["Event_StartCitizen"] == State.ENABLED, "StartEvent not enabled");
        require(msg.sender == participantAddresses["Citizen"], "Only Citizen can do this task");

        elementStates["Event_StartCitizen"] = State.DONE;
        logAudit("Event_StartCitizen");
        emit TaskCompleted("Event_StartCitizen");

        elementStates["Activity_SendRequestMunicipality"] = State.ENABLED;
    }

    function sendRequestToMunicipality() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SendRequestMunicipality"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Citizen"], "Only Citizen can do this task");

        require(elementStates["Event_StartCitizen"] == State.DONE, "Dependency not completed");

        elementStates["Activity_SendRequestMunicipality"] = State.DONE;
        logAudit("Activity_SendRequestMunicipality");
        emit TaskCompleted("Activity_SendRequestMunicipality");

        elementStates["Event_ReceiveRequest"] = State.ENABLED;
    }

    function documentsReceived() public nonReentrant whenNotPaused {
        require(elementStates["Activity_DocumentsReceived"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Citizen"], "Only Citizen can do this task");


        elementStates["Activity_DocumentsReceived"] = State.DONE;
        logAudit("Activity_DocumentsReceived");
        emit TaskCompleted("Activity_DocumentsReceived");

        elementStates["Activity_SendFeedback"] = State.ENABLED;
    }

    function sendFeedback() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SendFeedback"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Citizen"], "Only Citizen can do this task");

        require(elementStates["Activity_DocumentsReceived"] == State.DONE, "Dependency not completed");

        elementStates["Activity_SendFeedback"] = State.DONE;
        logAudit("Activity_SendFeedback");
        emit TaskCompleted("Activity_SendFeedback");

        elementStates["Event_EndCitizenProcess"] = State.ENABLED;
    }

    function completeRequestAndResendIt() public nonReentrant whenNotPaused {
        require(elementStates["Activity_CompleteRequestAndResend"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Citizen"], "Only Citizen can do this task");


        elementStates["Activity_CompleteRequestAndResend"] = State.DONE;
        logAudit("Activity_CompleteRequestAndResend");
        emit TaskCompleted("Activity_CompleteRequestAndResend");

        elementStates["Event_ReceiveRequest"] = State.ENABLED;
    }

    function elaborateRequest() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ElaborateRequest"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can do this task");

        require(elementStates["Gateway_CheckRequest"] == State.DONE, "Dependency not completed");

        elementStates["Activity_ElaborateRequest"] = State.DONE;
        logAudit("Activity_ElaborateRequest");
        emit TaskCompleted("Activity_ElaborateRequest");

        elementStates["Event_30DayDeadline"] = State.ENABLED;
    }

    function returnRequestToCitizen() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ReturnRequestToCitizen"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can do this task");

        require(elementStates["Gateway_CheckRequest"] == State.DONE, "Dependency not completed");

        elementStates["Activity_ReturnRequestToCitizen"] = State.DONE;
        logAudit("Activity_ReturnRequestToCitizen");
        emit TaskCompleted("Activity_ReturnRequestToCitizen");

        elementStates["Activity_CompleteRequestAndResend"] = State.ENABLED;
    }

    function sendDocuments() public nonReentrant whenNotPaused {
        require(elementStates["Activity_SendDocuments"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can do this task");

        require(
            elementStates["Event_15DayDeadline"] == State.DONE ||
            elementStates["Gateway_CheckDocuments"] == State.DONE,
            "At least one dependency must be completed"
        );

        elementStates["Activity_SendDocuments"] = State.DONE;
        logAudit("Activity_SendDocuments");
        emit TaskCompleted("Activity_SendDocuments");

        elementStates["Activity_DocumentsReceived"] = State.ENABLED;
    }

    function assignNewOperator() public nonReentrant whenNotPaused {
        require(elementStates["Activity_AssignNewOperator"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can do this task");

        require(elementStates["Gateway_CheckDocuments"] == State.DONE, "Dependency not completed");

        elementStates["Activity_AssignNewOperator"] = State.DONE;
        logAudit("Activity_AssignNewOperator");
        emit TaskCompleted("Activity_AssignNewOperator");

        elementStates["Event_15DayDeadline"] = State.ENABLED;
    }

    function receiveRequest() public nonReentrant whenNotPaused {
        require(elementStates["Event_ReceiveRequest"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can trigger this event");


        elementStates["Event_ReceiveRequest"] = State.DONE;
        logAudit("Event_ReceiveRequest");
        emit TaskCompleted("Event_ReceiveRequest");

        elementStates["Gateway_CheckRequest"] = State.ENABLED;
    }

    function f30DaysDeadlineForDocumentDelivery() public nonReentrant whenNotPaused {
        require(elementStates["Event_30DayDeadline"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can trigger this event");

        require(elementStates["Activity_ElaborateRequest"] == State.DONE, "Dependency not completed");

        elementStates["Event_30DayDeadline"] = State.DONE;
        logAudit("Event_30DayDeadline");
        emit TaskCompleted("Event_30DayDeadline");

        elementStates["Gateway_CheckDocuments"] = State.ENABLED;
    }

    function f15DaysExtendedDeadline() public nonReentrant whenNotPaused {
        require(elementStates["Event_15DayDeadline"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Municipality"], "Only Municipality can trigger this event");

        require(elementStates["Activity_AssignNewOperator"] == State.DONE, "Dependency not completed");

        elementStates["Event_15DayDeadline"] = State.DONE;
        logAudit("Event_15DayDeadline");
        emit TaskCompleted("Event_15DayDeadline");

        elementStates["Activity_SendDocuments"] = State.ENABLED;
    }

    function triggerTimereventdefinition30days() public nonReentrant whenNotPaused {
        require(elementStates["TimerEventDefinition_30Days"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerEventDefinition_30Days"], "Timer not expired yet");
        elementStates["TimerEventDefinition_30Days"] = State.DONE;
        logAudit("TimerEventDefinition_30Days");
        emit TaskCompleted("TimerEventDefinition_30Days");

    }

    function triggerTimereventdefinition15days() public nonReentrant whenNotPaused {
        require(elementStates["TimerEventDefinition_15Days"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerEventDefinition_15Days"], "Timer not expired yet");
        elementStates["TimerEventDefinition_15Days"] = State.DONE;
        logAudit("TimerEventDefinition_15Days");
        emit TaskCompleted("TimerEventDefinition_15Days");

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
