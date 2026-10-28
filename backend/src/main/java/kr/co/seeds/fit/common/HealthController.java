package kr.co.seeds.fit.common;

import java.time.OffsetDateTime;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/health")
public class HealthController {

    public record HealthResponse(String status, String db, OffsetDateTime serverTime) {}

    private final JdbcClient jdbc;

    public HealthController(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public HealthResponse health() {
        String db;
        try {
            Integer one = jdbc.sql("SELECT 1").query(Integer.class).single();
            db = (one != null && one == 1) ? "ok" : "unexpected";
        } catch (Exception e) {
            db = "down: " + e.getClass().getSimpleName();
        }
        return new HealthResponse("ok", db, OffsetDateTime.now());
    }
}
