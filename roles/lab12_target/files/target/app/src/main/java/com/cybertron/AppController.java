package com.cybertron;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
public class AppController {

    private static final Logger logger = LogManager.getLogger(AppController.class);

    private static final int TOTAL_RECORDS = 51;

    private static final Path DISPLAY_FILE = Paths.get("/app/data/records_display.json");

    private static final Path LOG_FILE = Paths.get("/app/logs/app.log");

    private final ObjectMapper objectMapper;

    @Autowired
    public AppController(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @GetMapping("/api/records")
    public ResponseEntity<Map<String, Object>> records() throws IOException {
        List<Map<String, Object>> records = objectMapper.readValue(
                Files.newInputStream(DISPLAY_FILE), new TypeReference<List<Map<String, Object>>>() {
                });

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("records", records);
        response.put("visibleCount", records.size());
        response.put("totalCount", TOTAL_RECORDS);
        response.put("locked", records.size() < TOTAL_RECORDS);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/login")
    public ResponseEntity<String> login(@RequestParam String username, @RequestParam String password) {
        logger.info("Login attempt for user: {}", username);

        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body("Invalid username or password.");
    }

    @GetMapping(value = "/api/logs", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> logs() throws IOException {
        if (!Files.exists(LOG_FILE)) {
            return ResponseEntity.ok("");
        }
        String content = new String(Files.readAllBytes(LOG_FILE));
        return ResponseEntity.ok(content);
    }
}