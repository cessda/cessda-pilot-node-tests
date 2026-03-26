package eu.cessda.pilotnode;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.PathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Serves the dashboard JSON data files from a configurable directory.
 *
 * <p>All requests to {@code /api/data/**} are resolved against the directory
 * configured by {@code dashboard.data-dir} in {@code application.properties}.
 * Only {@code .json} files are served; anything else returns 404.</p>
 *
 * <p>This keeps the JSON data files outside the application JAR so they can
 * be updated (by the data-collection scripts) without redeploying.</p>
 */
@RestController
@RequestMapping("/api/data")
public class DashboardDataController {

    private static final Logger log = LoggerFactory.getLogger(DashboardDataController.class);

    private final Path dataDir;

    public DashboardDataController(
            @Value("${dashboard.data-dir}") String dataDirPath) {
        this.dataDir = Paths.get(dataDirPath).toAbsolutePath().normalize();
        log.info("Dashboard data directory: {}", this.dataDir);
    }

    /**
     * Serves any {@code .json} file from under the data directory.
     *
     * <p>The URL path after {@code /api/data} is mapped directly to the
     * filesystem path under {@code dataDir}. Path traversal is prevented by
     * checking that the resolved path starts with {@code dataDir}.</p>
     */
    @GetMapping(value = "/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Resource> serveDataFile(HttpServletRequest request) {

        // Strip the /api/data prefix to get the relative path
        String requestUri = request.getRequestURI();
        String relativePath = requestUri.replaceFirst("^/api/data/?", "");

        // Only serve .json files
        if (!relativePath.endsWith(".json")) {
            return ResponseEntity.notFound().build();
        }

        // Resolve and normalise — prevents path traversal (e.g. ../../etc/passwd)
        Path resolved = dataDir.resolve(relativePath).normalize();
        if (!resolved.startsWith(dataDir)) {
            log.warn("Blocked path traversal attempt: {}", relativePath);
            return ResponseEntity.badRequest().build();
        }

        if (!Files.exists(resolved) || !Files.isRegularFile(resolved)) {
            log.debug("Data file not found: {}", resolved);
            return ResponseEntity.notFound().build();
        }

        log.debug("Serving data file: {}", resolved);
        return ResponseEntity.ok(new PathResource(resolved));
    }
}