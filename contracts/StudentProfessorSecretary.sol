// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Smart Contract automatically generated from a BPMN diagram
 * @dev Timer events handled using block numbers.
 */
contract StudentProfessorSecretary is ReentrancyGuard, Ownable, Pausable {

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
        participantAddresses["Professor"] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        participantAddresses["Student"] = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        participantAddresses["Secretary"] = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;

        elementStates["StartEvent_Professor"] = State.ENABLED;

        elementStates["Task_FixExamDate"] = State.DISABLED;
        elementStates["Task_ReceiveStudentList"] = State.DISABLED;
        elementStates["Task_EvaluateExams"] = State.DISABLED;
        elementStates["Task_SendScores"] = State.DISABLED;
        elementStates["Task_RegisterForExam"] = State.DISABLED;
        elementStates["Task_ReceiveScore"] = State.DISABLED;
        elementStates["Task_SendRejection"] = State.DISABLED;
        elementStates["Task_SendAcceptance"] = State.DISABLED;
        elementStates["Task_TakeExam"] = State.DISABLED;
        elementStates["Task_OpenRegistration"] = State.DISABLED;
        elementStates["Task_CloseRegistration"] = State.DISABLED;
        elementStates["Activity_ListStudentRegistered"] = State.DISABLED;
        elementStates["Task_SendStudentList"] = State.DISABLED;
        elementStates["Task_ReceiveScores"] = State.DISABLED;
        elementStates["Task_RegisterFinalScore"] = State.DISABLED;
        elementStates["Task_InformStudents"] = State.DISABLED;
        elementStates["Activity_AddStudentList"] = State.DISABLED;
        elementStates["Task_ReceiveDecision"] = State.DISABLED;
        elementStates["Gateway_ScoreDecision"] = State.DISABLED;
        elementStates["Event_15DaysTimer"] = State.DISABLED;
        elementStates["Event_StudentReceiveExamDate"] = State.DISABLED;
        elementStates["Event_7DaysTimer"] = State.DISABLED;
        elementStates["Event_SecretaryReceiveExamDate"] = State.DISABLED;
        elementStates["Event_7DaysRegistrationTimer"] = State.DISABLED;
        elementStates["Event_0qle08j"] = State.DISABLED;

        // [ADDED] Initialize all timer events at contract deployment
        // This means the timers start counting from now (block.number)
        blockLimits["TimerDefinition_15Days"] = block.number + 108000;
        elementStates["TimerDefinition_15Days"] = State.ENABLED;
        emit TimerScheduled("TimerDefinition_15Days", block.number + 108000);
        blockLimits["TimerDefinition_7Days"] = block.number + 50400;
        elementStates["TimerDefinition_7Days"] = State.ENABLED;
        emit TimerScheduled("TimerDefinition_7Days", block.number + 50400);
        blockLimits["TimerDefinition_7DaysReg"] = block.number + 50400;
        elementStates["TimerDefinition_7DaysReg"] = State.ENABLED;
        emit TimerScheduled("TimerDefinition_7DaysReg", block.number + 50400);

        {
            string[] memory depArr = new string[](1);
            depArr[0] = "Event_7DaysTimer";
            gatewayMap["Gateway_ScoreDecision"] = GatewayData({
                participantName: "Student",
                dependencies: depArr,
                yesTargetId: "Task_SendAcceptance",
                noTargetId: "Task_SendRejection"
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
        require(elementStates["StartEvent_Professor"] == State.ENABLED, "StartEvent not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can do this task");

        elementStates["StartEvent_Professor"] = State.DONE;
        logAudit("StartEvent_Professor");
        emit TaskCompleted("StartEvent_Professor");

        elementStates["Task_FixExamDate"] = State.ENABLED;
    }

    function fixExamDate() public nonReentrant whenNotPaused {
        require(elementStates["Task_FixExamDate"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can do this task");

        require(elementStates["StartEvent_Professor"] == State.DONE, "Dependency not completed");

        elementStates["Task_FixExamDate"] = State.DONE;
        logAudit("Task_FixExamDate");
        emit TaskCompleted("Task_FixExamDate");

        elementStates["Task_ReceiveStudentList"] = State.ENABLED;
        elementStates["Event_StudentReceiveExamDate"] = State.ENABLED;
        elementStates["Event_SecretaryReceiveExamDate"] = State.ENABLED;
    }

    function receiveStudentList() public nonReentrant whenNotPaused {
        require(elementStates["Task_ReceiveStudentList"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can do this task");

        require(elementStates["Task_FixExamDate"] == State.DONE, "Dependency not completed");

        elementStates["Task_ReceiveStudentList"] = State.DONE;
        logAudit("Task_ReceiveStudentList");
        emit TaskCompleted("Task_ReceiveStudentList");

        elementStates["Task_EvaluateExams"] = State.ENABLED;
    }

    function evaluateExams() public nonReentrant whenNotPaused {
        require(elementStates["Task_EvaluateExams"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can do this task");

        require(elementStates["Task_ReceiveStudentList"] == State.DONE, "Dependency not completed");

        elementStates["Task_EvaluateExams"] = State.DONE;
        logAudit("Task_EvaluateExams");
        emit TaskCompleted("Task_EvaluateExams");

        elementStates["Event_15DaysTimer"] = State.ENABLED;
    }

    function sendScores() public nonReentrant whenNotPaused {
        require(elementStates["Task_SendScores"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can do this task");

        require(elementStates["Event_15DaysTimer"] == State.DONE, "Dependency not completed");

        elementStates["Task_SendScores"] = State.DONE;
        logAudit("Task_SendScores");
        emit TaskCompleted("Task_SendScores");

        elementStates["Task_ReceiveScores"] = State.ENABLED;
    }

    function registerForExam() public nonReentrant whenNotPaused {
        require(elementStates["Task_RegisterForExam"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can do this task");

        require(elementStates["Event_StudentReceiveExamDate"] == State.DONE, "Dependency not completed");

        elementStates["Task_RegisterForExam"] = State.DONE;
        logAudit("Task_RegisterForExam");
        emit TaskCompleted("Task_RegisterForExam");

        elementStates["Task_TakeExam"] = State.ENABLED;
        elementStates["Event_0qle08j"] = State.ENABLED;
    }

    function receiveScore() public nonReentrant whenNotPaused {
        require(elementStates["Task_ReceiveScore"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can do this task");

        require(elementStates["Task_TakeExam"] == State.DONE, "Dependency not completed");

        elementStates["Task_ReceiveScore"] = State.DONE;
        logAudit("Task_ReceiveScore");
        emit TaskCompleted("Task_ReceiveScore");

        elementStates["Event_7DaysTimer"] = State.ENABLED;
    }

    function sendRejection() public nonReentrant whenNotPaused {
        require(elementStates["Task_SendRejection"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can do this task");

        require(elementStates["Gateway_ScoreDecision"] == State.DONE, "Dependency not completed");

        elementStates["Task_SendRejection"] = State.DONE;
        logAudit("Task_SendRejection");
        emit TaskCompleted("Task_SendRejection");

        elementStates["Task_ReceiveDecision"] = State.ENABLED;
    }

    function sendAcceptance() public nonReentrant whenNotPaused {
        require(elementStates["Task_SendAcceptance"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can do this task");

        require(elementStates["Gateway_ScoreDecision"] == State.DONE, "Dependency not completed");

        elementStates["Task_SendAcceptance"] = State.DONE;
        logAudit("Task_SendAcceptance");
        emit TaskCompleted("Task_SendAcceptance");

        elementStates["Task_ReceiveDecision"] = State.ENABLED;
    }

    function takeExam() public nonReentrant whenNotPaused {
        require(elementStates["Task_TakeExam"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can do this task");

        require(elementStates["Task_RegisterForExam"] == State.DONE, "Dependency not completed");

        elementStates["Task_TakeExam"] = State.DONE;
        logAudit("Task_TakeExam");
        emit TaskCompleted("Task_TakeExam");

        elementStates["Task_ReceiveScore"] = State.ENABLED;
        elementStates["Task_EvaluateExams"] = State.ENABLED;
    }

    function openRegistration() public nonReentrant whenNotPaused {
        require(elementStates["Task_OpenRegistration"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Event_SecretaryReceiveExamDate"] == State.DONE, "Dependency not completed");

        elementStates["Task_OpenRegistration"] = State.DONE;
        logAudit("Task_OpenRegistration");
        emit TaskCompleted("Task_OpenRegistration");

        elementStates["Event_7DaysRegistrationTimer"] = State.ENABLED;
    }

    function closeRegistration() public nonReentrant whenNotPaused {
        require(elementStates["Task_CloseRegistration"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Event_7DaysRegistrationTimer"] == State.DONE, "Dependency not completed");

        elementStates["Task_CloseRegistration"] = State.DONE;
        logAudit("Task_CloseRegistration");
        emit TaskCompleted("Task_CloseRegistration");

        elementStates["Activity_ListStudentRegistered"] = State.ENABLED;
    }

    function listStudentRegistered() public nonReentrant whenNotPaused {
        require(elementStates["Activity_ListStudentRegistered"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(
            elementStates["Task_CloseRegistration"] == State.DONE ||
            elementStates["Activity_AddStudentList"] == State.DONE,
            "At least one dependency must be completed"
        );

        elementStates["Activity_ListStudentRegistered"] = State.DONE;
        logAudit("Activity_ListStudentRegistered");
        emit TaskCompleted("Activity_ListStudentRegistered");

        elementStates["Task_SendStudentList"] = State.ENABLED;
    }

    function sendStudentList() public nonReentrant whenNotPaused {
        require(elementStates["Task_SendStudentList"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Activity_ListStudentRegistered"] == State.DONE, "Dependency not completed");

        elementStates["Task_SendStudentList"] = State.DONE;
        logAudit("Task_SendStudentList");
        emit TaskCompleted("Task_SendStudentList");

        elementStates["Task_ReceiveStudentList"] = State.ENABLED;
    }

    function receiveScores() public nonReentrant whenNotPaused {
        require(elementStates["Task_ReceiveScores"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");


        elementStates["Task_ReceiveScores"] = State.DONE;
        logAudit("Task_ReceiveScores");
        emit TaskCompleted("Task_ReceiveScores");

        elementStates["Task_InformStudents"] = State.ENABLED;
    }

    function registerFinalScore() public nonReentrant whenNotPaused {
        require(elementStates["Task_RegisterFinalScore"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Task_ReceiveDecision"] == State.DONE, "Dependency not completed");

        elementStates["Task_RegisterFinalScore"] = State.DONE;
        logAudit("Task_RegisterFinalScore");
        emit TaskCompleted("Task_RegisterFinalScore");

        elementStates["EndEvent_Secretary"] = State.ENABLED;
    }

    function informStudents() public nonReentrant whenNotPaused {
        require(elementStates["Task_InformStudents"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Task_ReceiveScores"] == State.DONE, "Dependency not completed");

        elementStates["Task_InformStudents"] = State.DONE;
        logAudit("Task_InformStudents");
        emit TaskCompleted("Task_InformStudents");

        elementStates["Task_ReceiveDecision"] = State.ENABLED;
        elementStates["Task_ReceiveScore"] = State.ENABLED;
    }

    function addStudentList() public nonReentrant whenNotPaused {
        require(elementStates["Activity_AddStudentList"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Event_0qle08j"] == State.DONE, "Dependency not completed");

        elementStates["Activity_AddStudentList"] = State.DONE;
        logAudit("Activity_AddStudentList");
        emit TaskCompleted("Activity_AddStudentList");

        elementStates["Activity_ListStudentRegistered"] = State.ENABLED;
    }

    function receiveDecision() public nonReentrant whenNotPaused {
        require(elementStates["Task_ReceiveDecision"] == State.ENABLED, "Task not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can do this task");

        require(elementStates["Task_InformStudents"] == State.DONE, "Dependency not completed");

        elementStates["Task_ReceiveDecision"] = State.DONE;
        logAudit("Task_ReceiveDecision");
        emit TaskCompleted("Task_ReceiveDecision");

        elementStates["Task_RegisterFinalScore"] = State.ENABLED;
    }

    function f15DaysDeadline() public nonReentrant whenNotPaused {
        require(elementStates["Event_15DaysTimer"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Professor"], "Only Professor can trigger this event");

        require(elementStates["Task_EvaluateExams"] == State.DONE, "Dependency not completed");

        elementStates["Event_15DaysTimer"] = State.DONE;
        logAudit("Event_15DaysTimer");
        emit TaskCompleted("Event_15DaysTimer");

        elementStates["Task_SendScores"] = State.ENABLED;
    }

    function studentReceiveExamDate() public nonReentrant whenNotPaused {
        require(elementStates["Event_StudentReceiveExamDate"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can trigger this event");

        require(elementStates["StartEvent_Student"] == State.DONE, "Dependency not completed");

        elementStates["Event_StudentReceiveExamDate"] = State.DONE;
        logAudit("Event_StudentReceiveExamDate");
        emit TaskCompleted("Event_StudentReceiveExamDate");

        elementStates["Task_RegisterForExam"] = State.ENABLED;
    }

    function f7DaysDeadline() public nonReentrant whenNotPaused {
        require(elementStates["Event_7DaysTimer"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Student"], "Only Student can trigger this event");

        require(elementStates["Task_ReceiveScore"] == State.DONE, "Dependency not completed");

        elementStates["Event_7DaysTimer"] = State.DONE;
        logAudit("Event_7DaysTimer");
        emit TaskCompleted("Event_7DaysTimer");

        elementStates["Gateway_ScoreDecision"] = State.ENABLED;
    }

    function secretaryReceiveExamDate() public nonReentrant whenNotPaused {
        require(elementStates["Event_SecretaryReceiveExamDate"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can trigger this event");

        require(elementStates["StartEvent_Secretary"] == State.DONE, "Dependency not completed");

        elementStates["Event_SecretaryReceiveExamDate"] = State.DONE;
        logAudit("Event_SecretaryReceiveExamDate");
        emit TaskCompleted("Event_SecretaryReceiveExamDate");

        elementStates["Task_OpenRegistration"] = State.ENABLED;
    }

    function f7DaysPeriod() public nonReentrant whenNotPaused {
        require(elementStates["Event_7DaysRegistrationTimer"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can trigger this event");

        require(elementStates["Task_OpenRegistration"] == State.DONE, "Dependency not completed");

        elementStates["Event_7DaysRegistrationTimer"] = State.DONE;
        logAudit("Event_7DaysRegistrationTimer");
        emit TaskCompleted("Event_7DaysRegistrationTimer");

        elementStates["Task_CloseRegistration"] = State.ENABLED;
    }

    function receiveExamRegistration() public nonReentrant whenNotPaused {
        require(elementStates["Event_0qle08j"] == State.ENABLED, "Event not enabled");
        require(msg.sender == participantAddresses["Secretary"], "Only Secretary can trigger this event");


        elementStates["Event_0qle08j"] = State.DONE;
        logAudit("Event_0qle08j");
        emit TaskCompleted("Event_0qle08j");

        elementStates["Activity_AddStudentList"] = State.ENABLED;
    }

    function triggerTimerdefinition15days() public nonReentrant whenNotPaused {
        require(elementStates["TimerDefinition_15Days"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerDefinition_15Days"], "Timer not expired yet");
        elementStates["TimerDefinition_15Days"] = State.DONE;
        logAudit("TimerDefinition_15Days");
        emit TaskCompleted("TimerDefinition_15Days");

    }

    function triggerTimerdefinition7days() public nonReentrant whenNotPaused {
        require(elementStates["TimerDefinition_7Days"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerDefinition_7Days"], "Timer not expired yet");
        elementStates["TimerDefinition_7Days"] = State.DONE;
        logAudit("TimerDefinition_7Days");
        emit TaskCompleted("TimerDefinition_7Days");

    }

    function triggerTimerdefinition7daysreg() public nonReentrant whenNotPaused {
        require(elementStates["TimerDefinition_7DaysReg"] == State.ENABLED, "Timer event not enabled");
        require(block.number >= blockLimits["TimerDefinition_7DaysReg"], "Timer not expired yet");
        elementStates["TimerDefinition_7DaysReg"] = State.DONE;
        logAudit("TimerDefinition_7DaysReg");
        emit TaskCompleted("TimerDefinition_7DaysReg");

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
