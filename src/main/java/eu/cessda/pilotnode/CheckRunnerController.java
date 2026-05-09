/*
 * SPDX-FileCopyrightText: 2026 CESSDA ERIC (support@cessda.eu)
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *    http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package eu.cessda.pilotnode;

import java.nio.file.Path;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.logging.Logger;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * REST controller that triggers the three data-collection checks
 * ({@code CheckNodeCapabilities}, {@code CheckCatalogueServices},
 * {@code CheckServiceUptime}) and exposes job status for polling.
 *
 * <h2>Endpoints</h2>
 * <pre>
 *   POST /api/run/node-capabilities   – run CheckNodeCapabilities
 *   POST /api/run/catalogue-services  – run CheckCatalogueServices
 *   POST /api/run/service-uptime      – run CheckServiceUptime
 *   GET  /api/run/{jobId}/status      – poll the status of any job
 *   GET  /api/run/status              – list all recent job statuses
 * </pre>
 *
 * <h2>Configuration (application.properties)</h2>
 * <pre>
 *   dashboard.data-dir   = ../dashboard/data   # already used by DashboardDataController
 *   check.node-name      = CESSDA              # NODE_NAME arg for all three checks
 *   check.api-key-argo   =                     # API key for CheckServiceUptime
 *   check.api-key-node   =                     # API key for CheckNodeCapabilities
 * </pre>
 *
 * <p>Jobs run asynchronously on a dedicated single-thread executor so that
 * only one job of each type can run at a time, and the HTTP request returns
 * immediately with a job ID. The caller polls {@code /api/run/{jobId}/status}
 * until the status is {@code DONE} or {@code ERROR}.</p>
 */
@RestController
@RequestMapping("/api/run")
public class CheckRunnerController {

    private static final Logger log = Logger.getLogger(CheckRunnerController.class.getName());

    // ── Config ────────────────────────────────────────────────────────────────

    private final String dataDirPath;
    private final String nodeName;
    private final String argoApiKey;
    private final String nodeApiKey;
    private final ObjectMapper mapper = new ObjectMapper();

    // ── State ─────────────────────────────────────────────────────────────────

    /**
     * One executor per check type keeps jobs serialised per type while allowing
     * different check types to run concurrently.
     */
    private final ExecutorService executor = Executors.newFixedThreadPool(3);

    /** Live and recent job records, keyed by jobId. */
    private final Map<String, JobRecord> jobs = new ConcurrentHashMap<>();

    // ── Constructor ───────────────────────────────────────────────────────────

    public CheckRunnerController(
            @Value("${dashboard.data-dir}")   String dataDirPath,
            @Value("${check.node-name:}")     String nodeName,
            @Value("${check.api-key-argo:}")  String argoApiKey,
            @Value("${check.api-key-node:}")  String nodeApiKey) {
        this.dataDirPath = dataDirPath;
        this.nodeName    = nodeName;
        this.argoApiKey  = argoApiKey;
        this.nodeApiKey  = nodeApiKey;
    }

    // ── Trigger endpoints ─────────────────────────────────────────────────────

    /**
     * Triggers {@link CheckNodeCapabilities}.
     *
     * <p>Requires {@code check.node-name} and {@code check.api-key-node} to be
     * set in {@code application.properties}.</p>
     */
    @PostMapping("/node-capabilities")
    public ResponseEntity<ObjectNode> runNodeCapabilities() {
        if (nodeApiKey.isBlank()) {
            return configError("check.api-key-node is not configured");
        }
        if (nodeName.isBlank()) {
            return configError("check.node-name is not configured");
        }

        String jobId = jobId("node-capabilities");
        JobRecord rec = new JobRecord(jobId, "node-capabilities");
        jobs.put(jobId, rec);

        executor.submit(() -> {
            rec.markRunning();
            try {
                Path dashDir = Path.of(dataDirPath);
                CheckNodeCapabilities checker = new CheckNodeCapabilities(
                        nodeApiKey,
                        CheckNodeCapabilities.OutputFormat.JSON,
                        dashDir);
                checker.run();
                rec.markDone("node_registry_summary.json written");
            } catch (Exception e) {
                log.warning("CheckNodeCapabilities failed" + e);
                rec.markError(e.getMessage());
            }
        });

        return ResponseEntity.accepted().body(statusBody(rec));
    }

    /**
     * Triggers {@link CheckCatalogueServices}.
     *
     * <p>Requires {@code check.node-name} to be set.</p>
     *
     * @param quantity optional max services to retrieve (default 10)
     */
    @PostMapping("/catalogue-services")
    public ResponseEntity<ObjectNode> runCatalogueServices(
            @RequestParam(defaultValue = "10") int quantity) {
        if (nodeName.isBlank()) {
            return configError("check.node-name is not configured");
        }

        String jobId = jobId("catalogue-services");
        JobRecord rec = new JobRecord(jobId, "catalogue-services");
        jobs.put(jobId, rec);

        executor.submit(() -> {
            rec.markRunning();
            try {
                // CheckCatalogueServices is a CLI-only class; invoke its logic
                // through main() using a String[] args contract.
                String[] args = {
                    nodeName,
                    String.valueOf(quantity),
                    dataDirPath
                };
                CheckCatalogueServices.main(args);
                rec.markDone("catalogue_services_report.json written");
            } catch (Exception e) {
                log.warning("CheckCatalogueServices failed" + e);
                rec.markError(e.getMessage());
            }
        });

        return ResponseEntity.accepted().body(statusBody(rec));
    }

    /**
     * Triggers {@link CheckServiceUptime}.
     *
     * <p>Requires {@code check.node-name} and {@code check.api-key-argo}.</p>
     *
     * @param startDate optional start date (YYYY-MM-DD, defaults to 30 days ago)
     * @param endDate   optional end date   (YYYY-MM-DD, defaults to today)
     */
    @PostMapping("/service-uptime")
    public ResponseEntity<ObjectNode> runServiceUptime(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {
        if (argoApiKey.isBlank()) {
            return configError("check.api-key-argo is not configured");
        }
        if (nodeName.isBlank()) {
            return configError("check.node-name is not configured");
        }

        LocalDate start = startDate != null
                ? LocalDate.parse(startDate, DateTimeFormatter.ISO_LOCAL_DATE)
                : LocalDate.now().minusDays(30);
        LocalDate end = endDate != null
                ? LocalDate.parse(endDate, DateTimeFormatter.ISO_LOCAL_DATE)
                : LocalDate.now();

        if (!start.isBefore(end)) {
            ObjectNode err = mapper.createObjectNode();
            err.put("error", "startDate must be before endDate");
            return ResponseEntity.badRequest().body(err);
        }

        String jobId = jobId("service-uptime");
        JobRecord rec = new JobRecord(jobId, "service-uptime");
        jobs.put(jobId, rec);

        executor.submit(() -> {
            rec.markRunning();
            try {
                CheckServiceUptime checker = new CheckServiceUptime(
                        nodeName, argoApiKey, start, end, Path.of(dataDirPath));
                checker.run();
                rec.markDone("argo_uptime_report.json written");
            } catch (Exception e) {
                log.warning("CheckServiceUptime failed" + e);
                rec.markError(e.getMessage());
            }
        });

        return ResponseEntity.accepted().body(statusBody(rec));
    }

    // ── Status endpoints ──────────────────────────────────────────────────────

    /** Returns the status of a single job by its ID. */
    @GetMapping("/{jobId}/status")
    public ResponseEntity<ObjectNode> getJobStatus(@PathVariable String jobId) {
        JobRecord rec = jobs.get(jobId);
        if (rec == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(statusBody(rec));
    }

    /** Returns the status of all recent jobs (most-recent last). */
    @GetMapping("/status")
    public ResponseEntity<Object> getAllStatuses() {
        var list = jobs.values().stream()
                .sorted((a, b) -> a.startedAt.compareTo(b.startedAt))
                .map(this::statusBody)
                .toList();
        return ResponseEntity.ok(list);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String jobId(String type) {
        return type + "-" + System.currentTimeMillis();
    }

    private ResponseEntity<ObjectNode> configError(String message) {
        log.warning("Configuration error:  " + message);
        ObjectNode err = mapper.createObjectNode();
        err.put("error", message);
        err.put("hint",  "Set the missing property in application.properties");
        return ResponseEntity.badRequest().body(err);
    }

    private ObjectNode statusBody(JobRecord rec) {
        ObjectNode n = mapper.createObjectNode();
        n.put("jobId",      rec.jobId);
        n.put("type",       rec.type);
        n.put("status",     rec.status.name());
        n.put("startedAt",  rec.startedAt);
        if (rec.finishedAt != null) n.put("finishedAt", rec.finishedAt);
        if (rec.message    != null) n.put("message",    rec.message);
        return n;
    }

    // ── JobRecord ─────────────────────────────────────────────────────────────

    enum JobStatus { QUEUED, RUNNING, DONE, ERROR }

    static final class JobRecord {
        final String    jobId;
        final String    type;
        final String    startedAt;
        volatile JobStatus status     = JobStatus.QUEUED;
        volatile String    finishedAt = null;
        volatile String    message    = null;

        JobRecord(String jobId, String type) {
            this.jobId     = jobId;
            this.type      = type;
            this.startedAt = OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        }

        void markRunning() { this.status = JobStatus.RUNNING; }

        void markDone(String msg) {
            this.status     = JobStatus.DONE;
            this.message    = msg;
            this.finishedAt = OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        }

        void markError(String msg) {
            this.status     = JobStatus.ERROR;
            this.message    = msg;
            this.finishedAt = OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        }
    }
}
