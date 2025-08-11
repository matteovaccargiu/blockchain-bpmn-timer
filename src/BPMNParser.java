package com.bpmntosolidity;

import org.camunda.bpm.model.bpmn.Bpmn;
import org.camunda.bpm.model.bpmn.BpmnModelInstance;
import org.camunda.bpm.model.bpmn.instance.*;
import org.camunda.bpm.model.bpmn.instance.TimeDuration; 
import org.camunda.bpm.model.xml.instance.ModelElementInstance;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.io.File;

/**
 * BPMN -> Smart Contract Parser
 * Example implementation that handles Timer Events on-chain
 * using block numbers instead of time in seconds.
 */
public class BPMNParser {

    private static void writeContractHeader(StringBuilder sb) {
        sb.append("// SPDX-License-Identifier: MIT\n");
        sb.append("pragma solidity ^0.8.20;\n\n");

        sb.append("import \"@openzeppelin/contracts/utils/ReentrancyGuard.sol\";\n");
        sb.append("import \"@openzeppelin/contracts/access/Ownable.sol\";\n");
        sb.append("import \"@openzeppelin/contracts/utils/Pausable.sol\";\n\n");

        sb.append("/**\n");
        sb.append(" * @title Smart Contract automatically generated from a BPMN diagram\n");
        sb.append(" * @dev Timer events handled using block numbers.\n");
        sb.append(" */\n");
    }

    private static void validateInputs(String contractName, Map<String, String> participantAddressMap) {
        // Validate the contract name
        if (contractName == null || contractName.trim().isEmpty()) {
            throw new IllegalArgumentException("Contract name cannot be empty");
        }

        // Check that the name is valid as a Solidity identifier
        if (!contractName.matches("^[a-zA-Z_][a-zA-Z0-9_]*$")) {
            throw new IllegalArgumentException(
                "Invalid contract name. Must start with a letter or underscore and contain only letters, numbers, or underscores."
            );
        }

        // Validate Ethereum addresses
        for (Map.Entry<String, String> entry : participantAddressMap.entrySet()) {
            String participant = entry.getKey();
            String address = entry.getValue();

            if (!isValidEthereumAddress(address)) {
                throw new IllegalArgumentException(
                    String.format("Invalid Ethereum address for participant '%s': %s", participant, address)
                );
            }
        }
    }

    private static boolean isValidEthereumAddress(String address) {
        // Basic check
        if (address == null || address.trim().isEmpty()) {
            return false;
        }
        // 0x + 40 hex characters
        return address.matches("^0x[0-9a-fA-F]{40}$");
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {

            System.out.print("Enter the BPMN file path: ");
            String filePath = scanner.nextLine();

            System.out.print("Enter the smart contract name: ");
            String contractName = scanner.nextLine();

            // Load the BPMN model
            BpmnModelInstance modelInstance;
            try (FileInputStream fis = new FileInputStream(filePath)) {
                modelInstance = Bpmn.readModelFromStream(fis);
            }

            // Read the participants from the BPMN model and ask for the Ethereum address
            Collection<Participant> participants = modelInstance.getModelElementsByType(Participant.class);
            Map<String, String> participantAddressMap = new LinkedHashMap<>();
            for (Participant p : participants) {
                String name = (p.getName() != null && !p.getName().isEmpty()) ? p.getName() : p.getId();
                System.out.println("Enter Ethereum address for '" + name + "': ");
                String addr = scanner.nextLine();
                participantAddressMap.put(name, addr);
            }

            // Validation
            validateInputs(contractName, participantAddressMap);

            // Mapping: process ID -> participant
            Map<String, String> processToParticipant = extractProcessParticipantMapping(modelInstance);

            // Extract BPMN elements
            Collection<StartEvent> startEvents = modelInstance.getModelElementsByType(StartEvent.class);
            Collection<EndEvent> endEvents = modelInstance.getModelElementsByType(EndEvent.class);
            Collection<Task> tasks = modelInstance.getModelElementsByType(Task.class);
            Collection<Gateway> gateways = modelInstance.getModelElementsByType(Gateway.class);
            Collection<IntermediateCatchEvent> intermediateEvents = modelInstance.getModelElementsByType(IntermediateCatchEvent.class);
            Collection<TimerEventDefinition> timerEvents = modelInstance.getModelElementsByType(TimerEventDefinition.class);

            if (startEvents.isEmpty() || endEvents.isEmpty()) {
                throw new RuntimeException("At least one StartEvent and one EndEvent are required in BPMN.");
            }

            StartEvent startEvent = startEvents.iterator().next();
            EndEvent endEvent = endEvents.iterator().next();

            // Generate the contract
            generateSolidityContract(
                contractName,
                startEvent.getId(),
                endEvent.getId(),
                tasks,
                gateways,
                intermediateEvents,
                timerEvents,
                modelInstance,
                processToParticipant,
                participantAddressMap
            );

            System.out.println("Contract successfully generated: " + contractName + ".sol");

        } catch (IllegalArgumentException e) {
            System.err.println("Validation error: " + e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // Map processId -> participantName
    public static Map<String, String> extractProcessParticipantMapping(BpmnModelInstance modelInstance) {
        Map<String, String> map = new HashMap<>();
        Collection<Participant> participants = modelInstance.getModelElementsByType(Participant.class);
        for (Participant p : participants) {
            org.camunda.bpm.model.bpmn.instance.Process proc = p.getProcess();
            if (proc != null) {
                String pid = proc.getId();
                String pname = (p.getName() != null && !p.getName().isEmpty()) ? p.getName() : p.getId();
                map.put(pid, pname);
            }
        }
        return map;
    }

    // Returns the IDs of the elements that point to elementId
    public static List<String> getDependencies(String elementId, BpmnModelInstance modelInstance) {
        List<String> deps = new ArrayList<>();
        Collection<SequenceFlow> seqFlows = modelInstance.getModelElementsByType(SequenceFlow.class);
        for (SequenceFlow f : seqFlows) {
            if (f.getTarget().getId().equals(elementId)) {
                deps.add(f.getSource().getId());
            }
        }
        return deps;
    }

    // Finds which participant is responsible for a given BPMN element
    public static String findParticipantForElement(
            FlowElement el,
            BpmnModelInstance modelInstance,
            Map<String, String> proc2part
    ) {
        ModelElementInstance parent = el.getParentElement();
        org.camunda.bpm.model.bpmn.instance.Process bpmnProc = null;
        while (parent != null) {
            if (parent instanceof org.camunda.bpm.model.bpmn.instance.Process) {
                bpmnProc = (org.camunda.bpm.model.bpmn.instance.Process) parent;
                break;
            }
            parent = parent.getParentElement();
        }
        if (bpmnProc == null) {
            return "UnknownParticipant";
        }
        String pid = bpmnProc.getId();
        return proc2part.getOrDefault(pid, "UnknownParticipant");
    }

    // Simple function name sanitizer for Solidity
    private static String sanitizeForSolidity(String name) {
        if (name == null || name.trim().isEmpty()) {
            return "unnamedTask";
        }
        String cleaned = name.replaceAll("[^A-Za-z0-9]", " ");
        String[] parts = cleaned.split("\\s+");
        StringBuilder sb = new StringBuilder();
        if (parts.length > 0) {
            sb.append(parts[0].toLowerCase());
        }
        for (int i = 1; i < parts.length; i++) {
            String p = parts[i].toLowerCase();
            sb.append(Character.toUpperCase(p.charAt(0))).append(p.substring(1));
        }
        if (sb.length() > 0 && Character.isDigit(sb.charAt(0))) {
            sb.insert(0, "f");
        }
        return sb.toString();
    }

    private static void generateAdminFunctions(StringBuilder sb) {
        sb.append("    function updateParticipantAddress(string memory participant, address newAddress) public onlyOwner {\n");
        sb.append("        require(newAddress != address(0), \"Invalid address\");\n");
        sb.append("        participantAddresses[participant] = newAddress;\n");
        sb.append("    }\n\n");

        sb.append("    function pause() public onlyOwner {\n");
        sb.append("        _pause();\n");
        sb.append("    }\n\n");

        sb.append("    function unpause() public onlyOwner {\n");
        sb.append("        _unpause();\n");
        sb.append("    }\n\n");

        sb.append("    function resetElementState(string memory elementId) public onlyOwner {\n");
        sb.append("        elementStates[elementId] = State.DISABLED;\n");
        sb.append("    }\n\n");
    }

    // Security analysis result class
    private static class SecurityAnalysisResult {
        List<String> slitherFindings = new ArrayList<>();
        List<String> customFindings = new ArrayList<>();
        boolean hasErrors = false;
    }

    private static void analyzeWithSlither(String fileName, SecurityAnalysisResult result)
            throws IOException, InterruptedException {

        String workingDirectory = System.getProperty("slither.workingDir", System.getProperty("user.dir"));
        String remap = System.getProperty("slither.remap", "@openzeppelin=node_modules/@openzeppelin");

        ProcessBuilder processBuilder = new ProcessBuilder(
            "slither",
            fileName,
            "--solc-remaps", remap
        );

        File workingDirFile = new File(workingDirectory);
        if (!workingDirFile.exists() || !workingDirFile.isDirectory()) {
            throw new IOException("Working directory " + workingDirectory + " does not exist or is not a directory.");
        }
        processBuilder.directory(workingDirFile);

        System.out.println("Running Slither analysis...");
        System.out.println("Command: " + String.join(" ", processBuilder.command()));

        processBuilder.redirectErrorStream(true);
        java.lang.Process process = processBuilder.start();

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            StringBuilder currentFinding = new StringBuilder();
            System.out.println("\n=== Vulnerability Analysis with Slither ===");

            while ((line = reader.readLine()) != null) {
                System.out.println(line);

                if (line.contains("Error:") || line.contains("error:")) {
                    result.hasErrors = true;
                    result.slitherFindings.add("Error: " + line);
                } else if (line.startsWith("INFO:Detectors:") || line.startsWith("WARNING:")) {
                    if (currentFinding.length() > 0) {
                        result.slitherFindings.add(currentFinding.toString());
                        currentFinding = new StringBuilder();
                    }
                    currentFinding.append(line).append("\n");
                } else if (currentFinding.length() > 0) {
                    currentFinding.append(line).append("\n");
                }
            }

            if (currentFinding.length() > 0) {
                result.slitherFindings.add(currentFinding.toString());
            }
        }

        int exitCode = process.waitFor();
        System.out.println("\n=== Analysis Result ===");
        if (result.hasErrors) {
            System.out.println("Errors occurred during Slither analysis.");
        } else if (exitCode != 0 || !result.slitherFindings.isEmpty()) {
            System.out.println("Slither detected possible warnings. Check the report for details.");
        } else {
            System.out.println("Slither did not detect critical vulnerabilities.");
        }
    }

    private static List<String> performCustomSecurityChecks(String fileName) throws IOException {
        List<String> customVulnerabilities = new ArrayList<>();
        String solidityCode = new String(Files.readAllBytes(Paths.get(fileName)));

        // Simple checks using regex
        if (solidityCode.contains(".call(") && !solidityCode.contains("require(success)")) {
            customVulnerabilities.add("Use of '.call' without success verification.");
        }

        Pattern publicFunction = Pattern.compile("function\\s+\\w+\\s*\\([^)]*\\)\\s*public");
        Matcher matcher = publicFunction.matcher(solidityCode);
        while (matcher.find()) {
            String functionSignature = matcher.group();
            int searchStart = matcher.end();
            int searchEnd = Math.min(searchStart + 200, solidityCode.length());
            String snippet = solidityCode.substring(searchStart, searchEnd);

            boolean hasSecurityCheck = snippet.contains("onlyOwner") ||
                                       snippet.contains("onlyParticipant") ||
                                       snippet.contains("nonReentrant") ||
                                       snippet.contains("whenNotPaused");

            if (!hasSecurityCheck) {
                customVulnerabilities.add("Public function without adequate security controls: " + functionSignature);
            }
        }

        if (solidityCode.contains(".transfer(") || solidityCode.contains(".send(")) {
            customVulnerabilities.add("Use of transfer/send instead of the recommended call pattern.");
        }

        Pattern publicState = Pattern.compile("(uint|int|address|bool|string)\\s+public\\s+\\w+");
        matcher = publicState.matcher(solidityCode);
        while (matcher.find()) {
            customVulnerabilities.add("Public state variable found: " + matcher.group() + ". Consider using private + getters.");
        }

        if (!customVulnerabilities.isEmpty()) {
            System.out.println("=== Detected Vulnerabilities (Custom Checks) ===");
            for (String vuln : customVulnerabilities) {
                System.out.println("- " + vuln);
            }
        } else {
            System.out.println("No vulnerabilities detected with custom checks.");
        }

        return customVulnerabilities;
    }

    private static void generateSecurityReport(SecurityAnalysisResult result) throws IOException {
        String reportFile = "SecurityReport_" + System.currentTimeMillis() + ".txt";
        try (FileWriter fw = new FileWriter(reportFile)) {
            fw.write("=== Smart Contract Security Report ===\n\n");

            // 1. Slither Analysis
            fw.write("1. Analysis with Slither:\n\n");
            if (result.slitherFindings.isEmpty()) {
                fw.write("   No critical vulnerabilities detected\n\n");
            } else {
                fw.write("   Analysis results:\n\n");
                fw.write("   (See console output for details.)\n\n");
            }

            // 2. Custom Security Checks
            fw.write("2. Custom Security Checks:\n");
            if (result.customFindings.isEmpty()) {
                fw.write("   All custom checks passed.\n\n");
            } else {
                for (String vuln : result.customFindings) {
                    fw.write("   " + vuln + "\n");
                }
            }

            fw.write("\n3. Deployment Recommendations:\n");
            fw.write("   - Test thoroughly on a testnet.\n");
            fw.write("   - Verify roles and permissions.\n");
            fw.write("   - Document participant addresses.\n\n");

            fw.write("4. BPMN Workflow Specific Notes:\n");
            fw.write("   - Ensure correct usage of gatewayAction(gatewayId, bool).\n");
            fw.write("   - Document each gateway's yes/no logic.\n");
        }

        System.out.println("Detailed security report generated: " + reportFile);
    }

    /**
     * Single gateway management:
     *  - GatewayData struct
     *  - mapping gatewayId -> GatewayData
     *  - single function gatewayAction(string, bool)
     *  - removal of code that generated separate functions for each gateway
     */
    public static void generateSolidityContract(
            String contractName,
            String startEventId,
            String endEventId,
            Collection<Task> tasks,
            Collection<Gateway> gateways,
            Collection<IntermediateCatchEvent> intermediateEvents,
            Collection<TimerEventDefinition> timerEvents,
            BpmnModelInstance modelInstance,
            Map<String, String> processToParticipant,
            Map<String, String> participantAddressMap
    ) throws IOException, InterruptedException {

        Collection<SequenceFlow> allSeqFlows = modelInstance.getModelElementsByType(SequenceFlow.class);
        Collection<MessageFlow> allMsgFlows = modelInstance.getModelElementsByType(MessageFlow.class);

        // Timer info
        Set<String> timerEventIds = new HashSet<>();
        // Save the block estimate directly in a map: timerId -> string with the number of blocks
        Map<String, String> timerDurations = new HashMap<>();

        // Retrieve TimerEventDefinitions and interpret the duration in "blocks"
        for (TimerEventDefinition ted : timerEvents) {
            timerEventIds.add(ted.getId());
            TimeDuration timeDuration = ted.getTimeDuration();
            if (timeDuration != null) {
                String isoDuration = timeDuration.getTextContent().trim();
                if (isoDuration.startsWith("P") && isoDuration.endsWith("D")) {
                    String daysStr = isoDuration.substring(1, isoDuration.length() - 1);
                    int days = Integer.parseInt(daysStr);

                    // Block estimate: ~7200 blocks/day assuming 12 seconds per block
                    int blockEstimate = days * 7200;
                    timerDurations.put(ted.getId(), String.valueOf(blockEstimate));
                } else {
                    // Default 30 days => 30 * 7200 = 216000 blocks
                    timerDurations.put(ted.getId(), String.valueOf(30 * 7200));
                }
            } else {
                // If the definition is missing, default 30 days
                timerDurations.put(ted.getId(), String.valueOf(30 * 7200));
            }
        }

        // Generate the contract
        StringBuilder sb = new StringBuilder();
        writeContractHeader(sb);

        sb.append("contract ").append(contractName).append(" is ReentrancyGuard, Ownable, Pausable {\n\n");
        sb.append("    enum State { DISABLED, ENABLED, DONE }\n\n");

        // Instead of timeLimits, we will use blockLimits
        sb.append("    mapping(string => State) public elementStates;\n");
        sb.append("    mapping(string => uint256) public blockLimits;\n");
        sb.append("    mapping(string => address) public participantAddresses;\n\n");

        sb.append("    struct AuditLog {\n");
        sb.append("        string taskId;\n");
        sb.append("        address user;\n");
        sb.append("        uint256 timestamp;\n");
        sb.append("    }\n\n");

        sb.append("    AuditLog[] public auditLogs;\n");
        sb.append("    event TaskCompleted(string taskId);\n\n");

        // TimerScheduled event to indicate the deadline block
        sb.append("    event TimerScheduled(string timerId, uint256 deadlineBlock);\n\n");

        // Gateway struct
        sb.append("    struct GatewayData {\n");
        sb.append("        string participantName;\n");
        sb.append("        string[] dependencies;\n");
        sb.append("        string yesTargetId;\n");
        sb.append("        string noTargetId;\n");
        sb.append("    }\n\n");

        sb.append("    mapping(string => GatewayData) public gatewayMap;\n\n");

        // Constructor with automatic initialization of gatewayMap
        sb.append("    constructor() Ownable(msg.sender) Pausable() {\n");

        // Assign participant addresses
        for (Map.Entry<String, String> e : participantAddressMap.entrySet()) {
            sb.append("        participantAddresses[\"")
              .append(e.getKey())
              .append("\"] = ")
              .append(e.getValue())
              .append(";\n");
        }
        sb.append("\n");

        // Enable the StartEvent
        sb.append("        elementStates[\"").append(startEventId).append("\"] = State.ENABLED;\n\n");

        // Disable tasks, gateways, and intermediate events (initially)
        for (Task t : tasks) {
            sb.append("        elementStates[\"").append(t.getId()).append("\"] = State.DISABLED;\n");
        }
        for (Gateway g : gateways) {
            sb.append("        elementStates[\"").append(g.getId()).append("\"] = State.DISABLED;\n");
        }
        for (IntermediateCatchEvent ice : intermediateEvents) {
            sb.append("        elementStates[\"").append(ice.getId()).append("\"] = State.DISABLED;\n");
        }
        sb.append("\n");
        
        // Snippet to initialize ALL timers at deployment ----------
        sb.append("        // [ADDED] Initialize all timer events at contract deployment\n");
        sb.append("        // This means the timers start counting from now (block.number)\n");
        for (TimerEventDefinition ted : timerEvents) {
            String tedId = ted.getId();
            String blocks = timerDurations.get(tedId);
            if (blocks == null) blocks = "216000"; // fallback

            // By enabling them now, they immediately start counting
            sb.append("        blockLimits[\"").append(tedId).append("\"] = block.number + ").append(blocks).append(";\n");
            sb.append("        elementStates[\"").append(tedId).append("\"] = State.ENABLED;\n");
            sb.append("        emit TimerScheduled(\"").append(tedId).append("\", block.number + ").append(blocks).append(");\n");
        }
        sb.append("\n");
        
        // Initialize gatewayMap for each gateway automatically
        for (Gateway gw : gateways) {
            String gwId = gw.getId();
            String participant = findParticipantForElement(gw, modelInstance, processToParticipant);
            if (participant == null || participant.trim().isEmpty()) {
                participant = "UnknownParticipant";
            }
            
            // Retrieve dependencies for the gateway
            List<String> deps = getDependencies(gw.getId(), modelInstance);
            
            // Determine yesTarget and noTarget based on SequenceFlows (and optionally MessageFlows)
            String yesTarget = "";
            String noTarget = "";
            for (SequenceFlow sf : allSeqFlows) {
                if (sf.getSource().equals(gw)) {
                    if (sf.getName() != null && sf.getName().equalsIgnoreCase("Yes")) {
                        yesTarget = sf.getTarget().getId();
                    } else if (sf.getName() != null && sf.getName().equalsIgnoreCase("No")) {
                        noTarget = sf.getTarget().getId();
                    }
                }
            }
            for (MessageFlow mf : allMsgFlows) {
                if (mf.getSource() instanceof FlowElement) {
                    FlowElement src = (FlowElement) mf.getSource();
                    if (src.getId().equals(gw.getId())) {
                        if (mf.getName() != null && mf.getName().equalsIgnoreCase("Yes")) {
                            yesTarget = ((FlowElement) mf.getTarget()).getId();
                        } else if (mf.getName() != null && mf.getName().equalsIgnoreCase("No")) {
                            noTarget = ((FlowElement) mf.getTarget()).getId();
                        }
                    }
                }
            }
            
            sb.append("        {\n");
            sb.append("            string[] memory depArr = new string[](").append(deps.size()).append(");\n");
            for (int i = 0; i < deps.size(); i++) {
                sb.append("            depArr[").append(i).append("] = \"").append(deps.get(i)).append("\";\n");
            }
            sb.append("            gatewayMap[\"").append(gwId).append("\"] = GatewayData({\n");
            sb.append("                participantName: \"").append(participant).append("\",\n");
            sb.append("                dependencies: depArr,\n");
            sb.append("                yesTargetId: \"").append(yesTarget).append("\",\n");
            sb.append("                noTargetId: \"").append(noTarget).append("\"\n");
            sb.append("            });\n");
            sb.append("        }\n");
        }
        
        sb.append("    }\n\n");

        // Admin functions
        generateAdminFunctions(sb);

        sb.append("    function logAudit(string memory taskId) private {\n");
        sb.append("        auditLogs.push(AuditLog({taskId: taskId, user: msg.sender, timestamp: block.timestamp}));\n");
        sb.append("    }\n\n");

        // =========== Start Event Function ===========
        FlowElement startFlowElement = modelInstance.getModelElementById(startEventId);
        String startEventParticipant = findParticipantForElement(startFlowElement, modelInstance, processToParticipant);
        boolean restrictStartEvent = true; // Set to false if you want the start event to be open to any caller

        sb.append("    function startEvent() public nonReentrant whenNotPaused {\n");
        sb.append("        require(elementStates[\"").append(startEventId).append("\"] == State.ENABLED, \"StartEvent not enabled\");\n");
        if (restrictStartEvent && !"UnknownParticipant".equals(startEventParticipant)) {
            sb.append("        require(msg.sender == participantAddresses[\"").append(startEventParticipant)
              .append("\"], \"Only ").append(startEventParticipant).append(" can do this task\");\n\n");
        } else {
            sb.append("        // Start event open to any caller\n\n");
        }

        sb.append("        elementStates[\"").append(startEventId).append("\"] = State.DONE;\n");
        sb.append("        logAudit(\"").append(startEventId).append("\");\n");
        sb.append("        emit TaskCompleted(\"").append(startEventId).append("\");\n\n");

        // SequenceFlow from the start event
        for (SequenceFlow flow : allSeqFlows) {
            if (flow.getSource().getId().equals(startEventId)) {
                String targetId = flow.getTarget().getId();
                if (timerEventIds.contains(targetId)) {
                    // If the target is a timer, set blockLimits and emit the TimerScheduled event
                    String blocks = timerDurations.get(targetId);
                    if (blocks == null) blocks = "216000"; // fallback
                    sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                    sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                } else {
                    sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                }
            }
        }
        // MessageFlow from the start event
        for (MessageFlow mf : allMsgFlows) {
            if (mf.getSource() instanceof FlowElement) {
                FlowElement src = (FlowElement) mf.getSource();
                if (src.getId().equals(startEventId)) {
                    String targetId = mf.getTarget().getId();
                    if (timerEventIds.contains(targetId)) {
                        String blocks = timerDurations.get(targetId);
                        if (blocks == null) blocks = "216000";
                        sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                        sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                    } else {
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    }
                }
            }
        }
        sb.append("    }\n\n");

        // =========== Task Functions ===========
        for (Task t : tasks) {
            String participant = findParticipantForElement(t, modelInstance, processToParticipant);
            String originalName = (t.getName() != null && !t.getName().isEmpty()) ? t.getName() : t.getId();
            String funcName = sanitizeForSolidity(originalName);

            sb.append("    function ").append(funcName).append("() public nonReentrant whenNotPaused {\n");
            sb.append("        require(elementStates[\"").append(t.getId()).append("\"] == State.ENABLED, \"NE\");\n");
            sb.append("        require(msg.sender == participantAddresses[\"").append(participant).append("\"], \"Only ")
              .append(participant).append(" can do this task\");\n\n");

            // Check dependencies
            List<String> deps = getDependencies(t.getId(), modelInstance);
            if (deps.size() == 1) {
                sb.append("        require(elementStates[\"").append(deps.get(0)).append("\"] == State.DONE, \"Dependency not completed\");\n");
            } else if (deps.size() > 1) {
                sb.append("        require(\n");
                for (int i = 0; i < deps.size(); i++) {
                    sb.append("            elementStates[\"").append(deps.get(i)).append("\"] == State.DONE");
                    if (i < deps.size() - 1) sb.append(" ||\n");
                    else sb.append(",\n");
                }
                sb.append("            \"At least one dependency must be completed\"\n");
                sb.append("        );\n");
            }

            sb.append("\n        elementStates[\"").append(t.getId()).append("\"] = State.DONE;\n");
            sb.append("        logAudit(\"").append(t.getId()).append("\");\n");
            sb.append("        emit TaskCompleted(\"").append(t.getId()).append("\");\n\n");

            // Handle successors
            for (SequenceFlow flow : allSeqFlows) {
                if (flow.getSource() == t) {
                    String targetId = flow.getTarget().getId();
                    if (timerEventIds.contains(targetId)) {
                        String blocks = timerDurations.get(targetId);
                        if (blocks == null) blocks = "216000";
                        sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                        sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                    } else {
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    }
                }
            }
            for (MessageFlow mf : allMsgFlows) {
                if (mf.getSource() == t) {
                    String targetId = mf.getTarget().getId();
                    if (timerEventIds.contains(targetId)) {
                        String blocks = timerDurations.get(targetId);
                        if (blocks == null) blocks = "216000";
                        sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                        sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                    } else {
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    }
                }
            }
            sb.append("    }\n\n");
        }

        // =========== Intermediate Catch Events ===========
        for (IntermediateCatchEvent ice : intermediateEvents) {
            String participant = findParticipantForElement(ice, modelInstance, processToParticipant);
            String originalName = (ice.getName() != null && !ice.getName().isEmpty()) ? ice.getName() : ice.getId();
            String funcName = sanitizeForSolidity(originalName);

            sb.append("    function ").append(funcName).append("() public nonReentrant whenNotPaused {\n");
            sb.append("        require(elementStates[\"").append(ice.getId()).append("\"] == State.ENABLED, \"Event not enabled\");\n");
            sb.append("        require(msg.sender == participantAddresses[\"").append(participant).append("\"], \"Only ")
              .append(participant).append(" can trigger this event\");\n\n");

            List<String> deps = getDependencies(ice.getId(), modelInstance);
            if (deps.size() == 1) {
                sb.append("        require(elementStates[\"").append(deps.get(0)).append("\"] == State.DONE, \"Dependency not completed\");\n");
            } else if (deps.size() > 1) {
                sb.append("        require(\n");
                for (int i = 0; i < deps.size(); i++) {
                    sb.append("            elementStates[\"").append(deps.get(i)).append("\"] == State.DONE");
                    if (i < deps.size() - 1) sb.append(" ||\n");
                    else sb.append(",\n");
                }
                sb.append("            \"At least one dependency must be completed\"\n");
                sb.append("        );\n");
            }

            sb.append("\n        elementStates[\"").append(ice.getId()).append("\"] = State.DONE;\n");
            sb.append("        logAudit(\"").append(ice.getId()).append("\");\n");
            sb.append("        emit TaskCompleted(\"").append(ice.getId()).append("\");\n\n");

            for (SequenceFlow flow : allSeqFlows) {
                if (flow.getSource() == ice) {
                    String targetId = flow.getTarget().getId();
                    if (timerEventIds.contains(targetId)) {
                        String blocks = timerDurations.get(targetId);
                        if (blocks == null) blocks = "216000";
                        sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                        sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                    } else {
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    }
                }
            }
            for (MessageFlow mf : allMsgFlows) {
                if (mf.getSource() == ice) {
                    String targetId = mf.getTarget().getId();
                    if (timerEventIds.contains(targetId)) {
                        String blocks = timerDurations.get(targetId);
                        if (blocks == null) blocks = "216000";
                        sb.append("        blockLimits[\"").append(targetId).append("\"] = block.number + ").append(blocks).append(";\n");
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                        sb.append("        emit TimerScheduled(\"").append(targetId).append("\", block.number + ").append(blocks).append(");\n");
                    } else {
                        sb.append("        elementStates[\"").append(targetId).append("\"] = State.ENABLED;\n");
                    }
                }
            }
            sb.append("    }\n\n");
        }

        // =========== Timer Events ============
        // Check: block.number >= blockLimits[timerId]
        for (TimerEventDefinition ted : timerEvents) {
            String timerId = ted.getId();
            // Fallback name
            String originalName = ted.getAttributeValue("name");
            if (originalName == null || originalName.trim().isEmpty()) {
                originalName = timerId;
            }
            String funcName = "trigger" + Character.toUpperCase(sanitizeForSolidity(originalName).charAt(0))
                              + sanitizeForSolidity(originalName).substring(1);

            sb.append("    function ").append(funcName).append("() public nonReentrant whenNotPaused {\n");
            sb.append("        require(elementStates[\"").append(timerId).append("\"] == State.ENABLED, \"Timer event not enabled\");\n");
            sb.append("        require(block.number >= blockLimits[\"").append(timerId).append("\"], \"Timer not expired yet\");\n");
            sb.append("        elementStates[\"").append(timerId).append("\"] = State.DONE;\n");
            sb.append("        logAudit(\"").append(timerId).append("\");\n");
            sb.append("        emit TaskCompleted(\"").append(timerId).append("\");\n\n");

            // Enable successors
            for (SequenceFlow flow : allSeqFlows) {
                if (flow.getSource().getId().equals(timerId)) {
                    sb.append("        elementStates[\"").append(flow.getTarget().getId()).append("\"] = State.ENABLED;\n");
                }
            }
            for (MessageFlow mf : allMsgFlows) {
                if (mf.getSource() instanceof FlowElement) {
                    FlowElement src = (FlowElement) mf.getSource();
                    if (src.getId().equals(timerId)) {
                        sb.append("        elementStates[\"").append(mf.getTarget().getId()).append("\"] = State.ENABLED;\n");
                    }
                }
            }
            sb.append("    }\n\n");
        }

        // =========== Single gateway function ===========
        sb.append("    function gatewayAction(string memory gatewayId, bool condition) public nonReentrant whenNotPaused {\n");
        sb.append("        GatewayData memory gdata = gatewayMap[gatewayId];\n\n");
        sb.append("        require(elementStates[gatewayId] == State.ENABLED, \"Gateway not enabled\");\n");
        sb.append("        require(msg.sender == participantAddresses[gdata.participantName], \"Only correct participant can call\");\n\n");

        sb.append("        // Dependencies must be DONE\n");
        sb.append("        for (uint i = 0; i < gdata.dependencies.length; i++) {\n");
        sb.append("            require(elementStates[gdata.dependencies[i]] == State.DONE, \"Dependency not completed\");\n");
        sb.append("        }\n\n");

        sb.append("        elementStates[gatewayId] = State.DONE;\n");
        sb.append("        logAudit(gatewayId);\n");
        sb.append("        emit TaskCompleted(gatewayId);\n\n");

        sb.append("        if (condition) {\n");
        sb.append("            if (bytes(gdata.yesTargetId).length > 0) {\n");
        sb.append("                elementStates[gdata.yesTargetId] = State.ENABLED;\n");
        sb.append("            }\n");
        sb.append("        } else {\n");
        sb.append("            if (bytes(gdata.noTargetId).length > 0) {\n");
        sb.append("                elementStates[gdata.noTargetId] = State.ENABLED;\n");
        sb.append("            }\n");
        sb.append("        }\n");
        sb.append("    }\n\n");

        sb.append("}\n");

        String contractContent = sb.toString();

        // Check for multiple SPDX identifiers
        if (contractContent.split("SPDX-License-Identifier").length > 2) {
            System.out.println("Warning: Multiple SPDX identifiers found.");
        }

        String fileName = contractName + ".sol";
        try (FileWriter fw = new FileWriter(fileName)) {
            fw.write(contractContent);
        }
        System.out.println("Smart contract generated: " + fileName);

        // Security analysis with Slither and custom checks
        SecurityAnalysisResult securityResult = new SecurityAnalysisResult();
        try {
            analyzeWithSlither(fileName, securityResult);
        } catch (Exception e) {
            System.err.println("Warning: Slither analysis failed: " + e.getMessage());
            securityResult.slitherFindings.add("Error during Slither analysis: " + e.getMessage());
        }

        try {
            List<String> customVulns = performCustomSecurityChecks(fileName);
            securityResult.customFindings.addAll(customVulns);
        } catch (Exception e) {
            System.err.println("Warning: Custom security checks failed: " + e.getMessage());
        }

        generateSecurityReport(securityResult);
    }
}

