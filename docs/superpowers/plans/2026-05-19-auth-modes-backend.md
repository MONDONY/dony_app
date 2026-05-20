# Auth Modes — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter le package `emailotp` (envoi et vérification d'OTP par email), mettre à jour `POST /auth/register` pour accepter les inscriptions par email (Google/Apple/OTP), et corriger `FirebaseTokenFilter` pour que le `FirebaseToken` décodé soit disponible même pour les nouveaux utilisateurs.

**Architecture:** Nouveau package `com.dony.api.emailotp` auto-contenu (Entity → Repository → Service → Controller + ResendEmailService). `POST /auth/email-otp/verify` retourne un Firebase Custom Token — le client l'utilise pour `signInWithCustomToken` puis appelle `POST /auth/register` normalement. `FirebaseTokenFilter` corrigé : le token décodé est toujours stocké dans le `SecurityContext`, y compris pour les nouveaux utilisateurs (fix de la ligne 78 qui passait `null`). `AuthService.createUser` route selon le `sign_in_provider` Firebase (`phone` / `google.com` / `apple.com` / `custom`).

**Tech Stack:** Spring Boot 3.4.x · Java 21 · JPA/Hibernate · BCryptPasswordEncoder · Firebase Admin SDK (Custom Tokens) · RestClient · Flyway · H2 (tests) · MockMvc · JaCoCo ≥ 90 %

> **Amendements requis au plan Flutter (2026-05-19-auth-modes-flutter.md) :**
> - Task 3 — `auth_remote_datasource.dart` : `verifyEmailOtp` retourne `Future<String>` (customToken) et non `Future<void>`
> - Task 3 — `auth_repository.dart` : idem
> - Task 2 — `_onEmailOtpVerify` dans `auth_bloc.dart` : après `authRepository.verifyEmailOtp()`, appeler `await _firebaseAuth.signInWithCustomToken(customToken)` avant d'émettre `AuthEmailOtpVerified(email)`

---

## Structure des fichiers

### Créer

| Fichier | Rôle |
|---------|------|
| `src/main/resources/db/migration/V88__email_otp_tokens.sql` | Table `email_otp_tokens` + index |
| `src/main/java/com/dony/api/emailotp/EmailOtpEntity.java` | Entité JPA (hors BaseEntity) |
| `src/main/java/com/dony/api/emailotp/EmailOtpRepository.java` | Repository JPA + 2 requêtes custom |
| `src/main/java/com/dony/api/emailotp/EmailOtpProperties.java` | `@ConfigurationProperties(prefix = "dony.email")` |
| `src/main/java/com/dony/api/emailotp/ResendEmailService.java` | Appel REST `POST https://api.resend.com/emails` |
| `src/main/java/com/dony/api/emailotp/EmailOtpService.java` | Logique métier : générer, rate-limit, BCrypt, vérifier, custom token |
| `src/main/java/com/dony/api/emailotp/dto/EmailOtpSendRequest.java` | DTO envoi |
| `src/main/java/com/dony/api/emailotp/dto/EmailOtpSendResponse.java` | DTO réponse envoi |
| `src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyRequest.java` | DTO vérification |
| `src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyResponse.java` | DTO réponse vérification (customToken) |
| `src/main/java/com/dony/api/emailotp/EmailOtpController.java` | `POST /auth/email-otp/send` + `POST /auth/email-otp/verify` |
| `src/test/java/com/dony/api/emailotp/EmailOtpServiceTest.java` | Tests unitaires service |
| `src/test/java/com/dony/api/emailotp/EmailOtpControllerIntegrationTest.java` | Tests intégration MockMvc |

### Modifier

| Fichier | Changements |
|---------|-------------|
| `src/main/resources/application.yml` | Section `dony.email` (resend-api-key, from-address, otp-template) |
| `src/main/resources/application-test.yml` | Section `dony.email` avec valeurs de test |
| `src/main/java/com/dony/api/config/SecurityConfig.java` | Bean `PasswordEncoder` (BCrypt strength 10) |
| `src/main/java/com/dony/api/config/FirebaseConfig.java` | Bean `FirebaseAuth` injectable |
| `src/main/java/com/dony/api/auth/FirebaseTokenFilter.java` | Ligne 78 : `null` → `decoded` pour nouveaux users |
| `src/main/java/com/dony/api/auth/UserRepository.java` | `existsByEmail` + `findByEmail` |
| `src/main/java/com/dony/api/auth/dto/RegisterRequest.java` | `phoneNumber` nullable, ajouter `email` nullable |
| `src/main/java/com/dony/api/auth/AuthService.java` | `register()` et `createUser()` avec routing par provider |
| `src/main/java/com/dony/api/auth/AuthController.java` | Extraire `decodedToken` du `SecurityContext` et le passer au service |
| `src/test/java/com/dony/api/auth/AuthServiceTest.java` | Nouveaux tests `createUser` par provider |

---

### Task 1 : Migration Flyway V88 — table email_otp_tokens

**Files:**
- Create: `src/main/resources/db/migration/V88__email_otp_tokens.sql`

- [ ] **Step 1 : Écrire la migration**

```sql
-- V88__email_otp_tokens.sql
CREATE TABLE email_otp_tokens (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email      VARCHAR(255) NOT NULL,
    code_hash  VARCHAR(60)  NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    used_at    TIMESTAMP,
    attempts   INT          NOT NULL DEFAULT 0,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_otp_email ON email_otp_tokens (email);
```

- [ ] **Step 2 : Vérifier que la migration s'applique sur base vide**

```bash
cd dony-back
docker compose -f docker-compose.dev.yml up -d
./mvnw flyway:migrate -Dspring.profiles.active=dev
./mvnw flyway:info  -Dspring.profiles.active=dev
```

Expected : `V88__email_otp_tokens` en status `Success`.

- [ ] **Step 3 : Commit**

```bash
git add src/main/resources/db/migration/V88__email_otp_tokens.sql
git commit -m "feat(emailotp): migration V88 — table email_otp_tokens"
```

---

### Task 2 : EmailOtpEntity + EmailOtpRepository

**Files:**
- Create: `src/main/java/com/dony/api/emailotp/EmailOtpEntity.java`
- Create: `src/main/java/com/dony/api/emailotp/EmailOtpRepository.java`

- [ ] **Step 1 : Écrire les tests qui échouent**

```java
// src/test/java/com/dony/api/emailotp/EmailOtpEntityTest.java
package com.dony.api.emailotp;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

class EmailOtpEntityTest {

    @Test
    void createdAt_setOnPrePersist() {
        EmailOtpEntity e = new EmailOtpEntity();
        e.onCreate();
        assertThat(e.getCreatedAt()).isNotNull();
    }

    @Test
    void attemptsDefaultsToZero() {
        EmailOtpEntity e = new EmailOtpEntity();
        assertThat(e.getAttempts()).isEqualTo(0);
    }
}
```

Lancer : `./mvnw test -Dtest=EmailOtpEntityTest -Dspring.profiles.active=test`
Expected : FAIL (classe introuvable)

- [ ] **Step 2 : Créer EmailOtpEntity**

```java
// src/main/java/com/dony/api/emailotp/EmailOtpEntity.java
package com.dony.api.emailotp;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@Entity
@Table(name = "email_otp_tokens")
public class EmailOtpEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 255)
    private String email;

    @Column(name = "code_hash", nullable = false, length = 60)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "used_at")
    private LocalDateTime usedAt;

    @Column(nullable = false)
    private int attempts = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void onCreate() {
        createdAt = LocalDateTime.now(ZoneOffset.UTC);
    }

    // Getters / Setters
    public UUID getId() { return id; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getCodeHash() { return codeHash; }
    public void setCodeHash(String codeHash) { this.codeHash = codeHash; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }
    public LocalDateTime getUsedAt() { return usedAt; }
    public void setUsedAt(LocalDateTime usedAt) { this.usedAt = usedAt; }
    public int getAttempts() { return attempts; }
    public void setAttempts(int attempts) { this.attempts = attempts; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
```

- [ ] **Step 3 : Créer EmailOtpRepository**

```java
// src/main/java/com/dony/api/emailotp/EmailOtpRepository.java
package com.dony.api.emailotp;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

public interface EmailOtpRepository extends JpaRepository<EmailOtpEntity, UUID> {

    @Query("SELECT COUNT(e) FROM EmailOtpEntity e WHERE e.email = :email AND e.createdAt > :since")
    long countByEmailSince(@Param("email") String email, @Param("since") LocalDateTime since);

    Optional<EmailOtpEntity> findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(String email);
}
```

- [ ] **Step 4 : Lancer les tests**

```bash
./mvnw test -Dtest=EmailOtpEntityTest -Dspring.profiles.active=test
```

Expected : PASS

- [ ] **Step 5 : Commit**

```bash
git add src/main/java/com/dony/api/emailotp/EmailOtpEntity.java \
        src/main/java/com/dony/api/emailotp/EmailOtpRepository.java \
        src/test/java/com/dony/api/emailotp/EmailOtpEntityTest.java
git commit -m "feat(emailotp): EmailOtpEntity + EmailOtpRepository"
```

---

### Task 3 : EmailOtpProperties + application.yml + ResendEmailService + PasswordEncoder bean + FirebaseAuth bean

**Files:**
- Create: `src/main/java/com/dony/api/emailotp/EmailOtpProperties.java`
- Create: `src/main/java/com/dony/api/emailotp/ResendEmailService.java`
- Modify: `src/main/resources/application.yml`
- Modify: `src/main/resources/application-test.yml`
- Modify: `src/main/java/com/dony/api/config/SecurityConfig.java`
- Modify: `src/main/java/com/dony/api/config/FirebaseConfig.java`

- [ ] **Step 1 : Créer EmailOtpProperties**

```java
// src/main/java/com/dony/api/emailotp/EmailOtpProperties.java
package com.dony.api.emailotp;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "dony.email")
public class EmailOtpProperties {

    private String resendApiKey = "";
    private String fromAddress = "noreply@dony.app";
    private String otpTemplate = "Ton code dony est : %s. Valable 10 minutes.";

    public String getResendApiKey() { return resendApiKey; }
    public void setResendApiKey(String resendApiKey) { this.resendApiKey = resendApiKey; }
    public String getFromAddress() { return fromAddress; }
    public void setFromAddress(String fromAddress) { this.fromAddress = fromAddress; }
    public String getOtpTemplate() { return otpTemplate; }
    public void setOtpTemplate(String otpTemplate) { this.otpTemplate = otpTemplate; }
}
```

- [ ] **Step 2 : Ajouter la section `dony.email` dans application.yml**

Ajouter à la fin de `src/main/resources/application.yml` (dans le bloc `dony:` existant) :

```yaml
  email:
    resend-api-key: ${RESEND_API_KEY:}
    from-address: noreply@dony.app
    otp-template: "Ton code dony est : %s. Valable 10 minutes."
```

- [ ] **Step 3 : Ajouter la section `dony.email` dans application-test.yml**

Ajouter à `src/main/resources/application-test.yml` :

```yaml
dony:
  email:
    resend-api-key: "test-resend-key"
    from-address: "noreply@test.dony.app"
    otp-template: "Test code: %s"
```

- [ ] **Step 4 : Ajouter le bean PasswordEncoder dans SecurityConfig**

Dans `src/main/java/com/dony/api/config/SecurityConfig.java`, ajouter après les champs de classe :

```java
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

// ... dans la classe SecurityConfig, ajouter le @Bean suivant :
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(10);
}
```

- [ ] **Step 5 : Ajouter le bean FirebaseAuth dans FirebaseConfig**

Dans `src/main/java/com/dony/api/config/FirebaseConfig.java`, ajouter après le bean `firestore()` :

```java
import com.google.firebase.auth.FirebaseAuth;

// ... dans la classe FirebaseConfig :
@Bean
public FirebaseAuth firebaseAuth() {
    if (FirebaseApp.getApps().isEmpty()) {
        log.warn("FirebaseAuth bean unavailable — Firebase not initialized (test/ci mode)");
        return null;
    }
    return FirebaseAuth.getInstance();
}
```

- [ ] **Step 6 : Créer ResendEmailService**

```java
// src/main/java/com/dony/api/emailotp/ResendEmailService.java
package com.dony.api.emailotp;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

@Service
public class ResendEmailService {

    private final RestClient restClient;
    private final String fromAddress;
    private final String otpTemplate;

    public ResendEmailService(EmailOtpProperties props) {
        this.fromAddress = props.getFromAddress();
        this.otpTemplate = props.getOtpTemplate();
        this.restClient = RestClient.builder()
                .baseUrl("https://api.resend.com")
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + props.getResendApiKey())
                .build();
    }

    public void sendOtp(String to, String code) {
        Map<String, Object> payload = Map.of(
                "from", fromAddress,
                "to", List.of(to),
                "subject", "Ton code dony",
                "text", String.format(otpTemplate, code)
        );
        restClient.post()
                .uri("/emails")
                .contentType(MediaType.APPLICATION_JSON)
                .body(payload)
                .retrieve()
                .toBodilessEntity();
    }
}
```

- [ ] **Step 7 : Vérifier que le projet compile**

```bash
./mvnw compile -Dspring.profiles.active=test
```

Expected : `BUILD SUCCESS`

- [ ] **Step 8 : Commit**

```bash
git add src/main/java/com/dony/api/emailotp/EmailOtpProperties.java \
        src/main/java/com/dony/api/emailotp/ResendEmailService.java \
        src/main/resources/application.yml \
        src/main/resources/application-test.yml \
        src/main/java/com/dony/api/config/SecurityConfig.java \
        src/main/java/com/dony/api/config/FirebaseConfig.java
git commit -m "feat(emailotp): EmailOtpProperties + ResendEmailService + beans PasswordEncoder + FirebaseAuth"
```

---

### Task 4 : EmailOtpService (TDD)

**Files:**
- Create: `src/main/java/com/dony/api/emailotp/EmailOtpService.java`
- Create: `src/test/java/com/dony/api/emailotp/EmailOtpServiceTest.java`

- [ ] **Step 1 : Écrire les tests qui échouent**

```java
// src/test/java/com/dony/api/emailotp/EmailOtpServiceTest.java
package com.dony.api.emailotp;

import com.dony.api.common.DonyBusinessException;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("EmailOtpService — tests unitaires")
class EmailOtpServiceTest {

    @Mock private EmailOtpRepository emailOtpRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private ResendEmailService resendEmailService;
    @Mock private FirebaseAuth firebaseAuth;
    @InjectMocks private EmailOtpService emailOtpService;

    private static final String EMAIL = "test@example.com";

    @Nested
    @DisplayName("sendOtp")
    class SendOtp {

        @Test
        @DisplayName("succès — sauvegarde token et envoie email")
        void success() {
            when(emailOtpRepository.countByEmailSince(eq(EMAIL), any())).thenReturn(0L);
            when(passwordEncoder.encode(anyString())).thenReturn("$2a$10$hashed");
            when(emailOtpRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            var result = emailOtpService.sendOtp(EMAIL);

            assertThat(result).isNotNull();
            verify(emailOtpRepository).save(argThat(e ->
                    EMAIL.equals(e.getEmail()) && "$2a$10$hashed".equals(e.getCodeHash())));
            verify(resendEmailService).sendOtp(eq(EMAIL), argThat(code ->
                    code.matches("\\d{6}")));
        }

        @Test
        @DisplayName("429 — 3 envois ou plus dans la fenêtre de 5 min")
        void rateLimitExceeded() {
            when(emailOtpRepository.countByEmailSince(eq(EMAIL), any())).thenReturn(3L);

            assertThatThrownBy(() -> emailOtpService.sendOtp(EMAIL))
                    .isInstanceOf(DonyBusinessException.class)
                    .extracting(e -> ((DonyBusinessException) e).getStatus())
                    .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);

            verify(emailOtpRepository, never()).save(any());
            verify(resendEmailService, never()).sendOtp(any(), any());
        }
    }

    @Nested
    @DisplayName("verifyOtp")
    class VerifyOtp {

        private EmailOtpEntity validToken() {
            EmailOtpEntity t = new EmailOtpEntity();
            t.setEmail(EMAIL);
            t.setCodeHash("$2a$10$hash");
            t.setExpiresAt(LocalDateTime.now(ZoneOffset.UTC).plusMinutes(5));
            t.setAttempts(0);
            return t;
        }

        @Test
        @DisplayName("succès — retourne customToken Firebase")
        void success() throws Exception {
            EmailOtpEntity token = validToken();
            when(emailOtpRepository.findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(EMAIL))
                    .thenReturn(Optional.of(token));
            when(passwordEncoder.matches("123456", "$2a$10$hash")).thenReturn(true);
            when(firebaseAuth.createCustomToken(EMAIL)).thenReturn("firebase-custom-token");
            when(emailOtpRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            String result = emailOtpService.verifyOtp(EMAIL, "123456");

            assertThat(result).isEqualTo("firebase-custom-token");
            assertThat(token.getUsedAt()).isNotNull();
        }

        @Test
        @DisplayName("400 — aucun token non utilisé")
        void noTokenFound() {
            when(emailOtpRepository.findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(EMAIL))
                    .thenReturn(Optional.empty());

            assertThatThrownBy(() -> emailOtpService.verifyOtp(EMAIL, "123456"))
                    .isInstanceOf(DonyBusinessException.class)
                    .extracting(e -> ((DonyBusinessException) e).getStatus())
                    .isEqualTo(HttpStatus.BAD_REQUEST);
        }

        @Test
        @DisplayName("429 — trop de tentatives échouées")
        void tooManyAttempts() {
            EmailOtpEntity token = validToken();
            token.setAttempts(5);
            when(emailOtpRepository.findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(EMAIL))
                    .thenReturn(Optional.of(token));

            assertThatThrownBy(() -> emailOtpService.verifyOtp(EMAIL, "123456"))
                    .isInstanceOf(DonyBusinessException.class)
                    .extracting(e -> ((DonyBusinessException) e).getStatus())
                    .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        }

        @Test
        @DisplayName("400 — token expiré")
        void tokenExpired() {
            EmailOtpEntity token = validToken();
            token.setExpiresAt(LocalDateTime.now(ZoneOffset.UTC).minusMinutes(1));
            when(emailOtpRepository.findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(EMAIL))
                    .thenReturn(Optional.of(token));

            assertThatThrownBy(() -> emailOtpService.verifyOtp(EMAIL, "123456"))
                    .isInstanceOf(DonyBusinessException.class)
                    .extracting(e -> ((DonyBusinessException) e).getStatus())
                    .isEqualTo(HttpStatus.BAD_REQUEST);
        }

        @Test
        @DisplayName("400 — code BCrypt invalide, incrémente attempts")
        void invalidCode() {
            EmailOtpEntity token = validToken();
            when(emailOtpRepository.findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(EMAIL))
                    .thenReturn(Optional.of(token));
            when(passwordEncoder.matches("000000", "$2a$10$hash")).thenReturn(false);
            when(emailOtpRepository.save(any())).thenAnswer(i -> i.getArgument(0));

            assertThatThrownBy(() -> emailOtpService.verifyOtp(EMAIL, "000000"))
                    .isInstanceOf(DonyBusinessException.class)
                    .extracting(e -> ((DonyBusinessException) e).getStatus())
                    .isEqualTo(HttpStatus.BAD_REQUEST);

            assertThat(token.getAttempts()).isEqualTo(1);
        }
    }
}
```

Lancer : `./mvnw test -Dtest=EmailOtpServiceTest -Dspring.profiles.active=test`
Expected : FAIL (classe `EmailOtpService` introuvable)

- [ ] **Step 2 : Créer EmailOtpService**

```java
// src/main/java/com/dony/api/emailotp/EmailOtpService.java
package com.dony.api.emailotp;

import com.dony.api.common.DonyBusinessException;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

@Service
@Transactional
public class EmailOtpService {

    private static final Logger log = LoggerFactory.getLogger(EmailOtpService.class);

    private static final int MAX_SENDS_PER_WINDOW = 3;
    private static final int RATE_WINDOW_MINUTES  = 5;
    private static final int MAX_ATTEMPTS         = 5;
    private static final int OTP_VALID_MINUTES    = 10;

    private final EmailOtpRepository emailOtpRepository;
    private final PasswordEncoder passwordEncoder;
    private final ResendEmailService resendEmailService;
    private final FirebaseAuth firebaseAuth;

    public EmailOtpService(EmailOtpRepository emailOtpRepository,
                           PasswordEncoder passwordEncoder,
                           ResendEmailService resendEmailService,
                           @Autowired(required = false) FirebaseAuth firebaseAuth) {
        this.emailOtpRepository = emailOtpRepository;
        this.passwordEncoder    = passwordEncoder;
        this.resendEmailService = resendEmailService;
        this.firebaseAuth       = firebaseAuth;
    }

    public java.time.Instant sendOtp(String email) {
        LocalDateTime since = LocalDateTime.now(ZoneOffset.UTC).minusMinutes(RATE_WINDOW_MINUTES);
        if (emailOtpRepository.countByEmailSince(email, since) >= MAX_SENDS_PER_WINDOW) {
            throw new DonyBusinessException(
                    HttpStatus.TOO_MANY_REQUESTS, "rate-limit",
                    "Too Many Requests", "Trop de tentatives, réessaie dans 5 min");
        }

        String code = String.format("%06d", new SecureRandom().nextInt(1_000_000));
        LocalDateTime expiresAt = LocalDateTime.now(ZoneOffset.UTC).plusMinutes(OTP_VALID_MINUTES);

        EmailOtpEntity entity = new EmailOtpEntity();
        entity.setEmail(email);
        entity.setCodeHash(passwordEncoder.encode(code));
        entity.setExpiresAt(expiresAt);
        emailOtpRepository.save(entity);

        resendEmailService.sendOtp(email, code);

        return expiresAt.toInstant(ZoneOffset.UTC);
    }

    public String verifyOtp(String email, String code) {
        EmailOtpEntity token = emailOtpRepository
                .findTopByEmailAndUsedAtIsNullOrderByCreatedAtDesc(email)
                .orElseThrow(() -> new DonyBusinessException(
                        HttpStatus.BAD_REQUEST, "otp-invalid",
                        "Invalid OTP", "Code invalide ou expiré"));

        if (token.getAttempts() >= MAX_ATTEMPTS) {
            throw new DonyBusinessException(
                    HttpStatus.TOO_MANY_REQUESTS, "otp-attempts-exceeded",
                    "Too Many Attempts", "Trop de tentatives échouées");
        }

        if (LocalDateTime.now(ZoneOffset.UTC).isAfter(token.getExpiresAt())) {
            throw new DonyBusinessException(
                    HttpStatus.BAD_REQUEST, "otp-expired",
                    "OTP Expired", "Code expiré");
        }

        if (!passwordEncoder.matches(code, token.getCodeHash())) {
            token.setAttempts(token.getAttempts() + 1);
            emailOtpRepository.save(token);
            throw new DonyBusinessException(
                    HttpStatus.BAD_REQUEST, "otp-invalid",
                    "Invalid OTP", "Code invalide");
        }

        token.setUsedAt(LocalDateTime.now(ZoneOffset.UTC));
        emailOtpRepository.save(token);

        if (firebaseAuth == null) {
            log.warn("FirebaseAuth not available — returning null custom token (test mode)");
            return null;
        }
        try {
            return firebaseAuth.createCustomToken(email);
        } catch (FirebaseAuthException e) {
            throw new DonyBusinessException(
                    HttpStatus.INTERNAL_SERVER_ERROR, "firebase-error",
                    "Firebase Error", "Erreur lors de la création du token");
        }
    }
}
```

- [ ] **Step 3 : Lancer les tests**

```bash
./mvnw test -Dtest=EmailOtpServiceTest -Dspring.profiles.active=test
```

Expected : tous PASS (8 tests)

- [ ] **Step 4 : Commit**

```bash
git add src/main/java/com/dony/api/emailotp/EmailOtpService.java \
        src/test/java/com/dony/api/emailotp/EmailOtpServiceTest.java
git commit -m "feat(emailotp): EmailOtpService (TDD) — send rate-limit + BCrypt verify + custom token"
```

---

### Task 5 : DTOs + EmailOtpController (TDD)

**Files:**
- Create: `src/main/java/com/dony/api/emailotp/dto/EmailOtpSendRequest.java`
- Create: `src/main/java/com/dony/api/emailotp/dto/EmailOtpSendResponse.java`
- Create: `src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyRequest.java`
- Create: `src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyResponse.java`
- Create: `src/main/java/com/dony/api/emailotp/EmailOtpController.java`
- Create: `src/test/java/com/dony/api/emailotp/EmailOtpControllerIntegrationTest.java`

- [ ] **Step 1 : Créer les DTOs**

```java
// src/main/java/com/dony/api/emailotp/dto/EmailOtpSendRequest.java
package com.dony.api.emailotp.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record EmailOtpSendRequest(
    @NotBlank(message = "L'email est obligatoire")
    @Email(message = "Format email invalide")
    String email
) {}
```

```java
// src/main/java/com/dony/api/emailotp/dto/EmailOtpSendResponse.java
package com.dony.api.emailotp.dto;

import java.time.Instant;

public record EmailOtpSendResponse(Instant expiresAt) {}
```

```java
// src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyRequest.java
package com.dony.api.emailotp.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EmailOtpVerifyRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 6, max = 6, message = "Le code doit faire 6 chiffres") String code
) {}
```

```java
// src/main/java/com/dony/api/emailotp/dto/EmailOtpVerifyResponse.java
package com.dony.api.emailotp.dto;

public record EmailOtpVerifyResponse(String customToken) {}
```

- [ ] **Step 2 : Écrire les tests d'intégration qui échouent**

```java
// src/test/java/com/dony/api/emailotp/EmailOtpControllerIntegrationTest.java
package com.dony.api.emailotp;

import com.dony.api.common.DonyBusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.dony.api.emailotp.dto.EmailOtpSendRequest;
import com.dony.api.emailotp.dto.EmailOtpVerifyRequest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
@DisplayName("EmailOtpController — intégration MockMvc")
class EmailOtpControllerIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @MockBean  private EmailOtpService emailOtpService;

    // ─── POST /auth/email-otp/send ────────────────────────────────────────────

    @Test
    @DisplayName("send 200 — retourne expiresAt")
    void send_success() throws Exception {
        Instant expiry = Instant.parse("2026-05-19T10:15:00Z");
        when(emailOtpService.sendOtp("user@example.com")).thenReturn(expiry);

        mockMvc.perform(post("/auth/email-otp/send")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new EmailOtpSendRequest("user@example.com"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expiresAt").value("2026-05-19T10:15:00Z"));
    }

    @Test
    @DisplayName("send 422 — email invalide")
    void send_invalidEmail() throws Exception {
        mockMvc.perform(post("/auth/email-otp/send")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"not-an-email\"}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    @DisplayName("send 429 — rate-limit atteint")
    void send_rateLimitExceeded() throws Exception {
        when(emailOtpService.sendOtp(anyString()))
                .thenThrow(new DonyBusinessException(
                        HttpStatus.TOO_MANY_REQUESTS, "rate-limit",
                        "Too Many Requests", "Trop de tentatives, réessaie dans 5 min"));

        mockMvc.perform(post("/auth/email-otp/send")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new EmailOtpSendRequest("user@example.com"))))
                .andExpect(status().isTooManyRequests());
    }

    // ─── POST /auth/email-otp/verify ──────────────────────────────────────────

    @Test
    @DisplayName("verify 200 — retourne customToken")
    void verify_success() throws Exception {
        when(emailOtpService.verifyOtp("user@example.com", "123456"))
                .thenReturn("firebase-custom-token");

        mockMvc.perform(post("/auth/email-otp/verify")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new EmailOtpVerifyRequest("user@example.com", "123456"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customToken").value("firebase-custom-token"));
    }

    @Test
    @DisplayName("verify 400 — code invalide")
    void verify_invalidCode() throws Exception {
        when(emailOtpService.verifyOtp(anyString(), anyString()))
                .thenThrow(new DonyBusinessException(
                        HttpStatus.BAD_REQUEST, "otp-invalid",
                        "Invalid OTP", "Code invalide"));

        mockMvc.perform(post("/auth/email-otp/verify")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new EmailOtpVerifyRequest("user@example.com", "000000"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("verify 429 — trop de tentatives")
    void verify_tooManyAttempts() throws Exception {
        when(emailOtpService.verifyOtp(anyString(), anyString()))
                .thenThrow(new DonyBusinessException(
                        HttpStatus.TOO_MANY_REQUESTS, "otp-attempts-exceeded",
                        "Too Many Attempts", "Trop de tentatives"));

        mockMvc.perform(post("/auth/email-otp/verify")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new EmailOtpVerifyRequest("user@example.com", "000000"))))
                .andExpect(status().isTooManyRequests());
    }
}
```

Lancer : `./mvnw test -Dtest=EmailOtpControllerIntegrationTest -Dspring.profiles.active=test`
Expected : FAIL (contrôleur introuvable → 404)

- [ ] **Step 3 : Créer EmailOtpController**

```java
// src/main/java/com/dony/api/emailotp/EmailOtpController.java
package com.dony.api.emailotp;

import com.dony.api.emailotp.dto.EmailOtpSendRequest;
import com.dony.api.emailotp.dto.EmailOtpSendResponse;
import com.dony.api.emailotp.dto.EmailOtpVerifyRequest;
import com.dony.api.emailotp.dto.EmailOtpVerifyResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth/email-otp")
public class EmailOtpController {

    private final EmailOtpService emailOtpService;

    public EmailOtpController(EmailOtpService emailOtpService) {
        this.emailOtpService = emailOtpService;
    }

    @PostMapping("/send")
    public ResponseEntity<EmailOtpSendResponse> send(@Valid @RequestBody EmailOtpSendRequest request) {
        var expiresAt = emailOtpService.sendOtp(request.email());
        return ResponseEntity.ok(new EmailOtpSendResponse(expiresAt));
    }

    @PostMapping("/verify")
    public ResponseEntity<EmailOtpVerifyResponse> verify(@Valid @RequestBody EmailOtpVerifyRequest request) {
        String customToken = emailOtpService.verifyOtp(request.email(), request.code());
        return ResponseEntity.ok(new EmailOtpVerifyResponse(customToken));
    }
}
```

> **Note SecurityConfig :** `/auth/**` est déjà en `permitAll()` — aucun changement nécessaire.

- [ ] **Step 4 : Lancer les tests**

```bash
./mvnw test -Dtest=EmailOtpControllerIntegrationTest -Dspring.profiles.active=test
```

Expected : tous PASS (7 tests)

- [ ] **Step 5 : Commit**

```bash
git add src/main/java/com/dony/api/emailotp/ \
        src/test/java/com/dony/api/emailotp/EmailOtpControllerIntegrationTest.java
git commit -m "feat(emailotp): DTOs + EmailOtpController (TDD)"
```

---

### Task 6 : FirebaseTokenFilter + UserRepository + RegisterRequest + AuthService (TDD)

**Files:**
- Modify: `src/main/java/com/dony/api/auth/FirebaseTokenFilter.java`
- Modify: `src/main/java/com/dony/api/auth/UserRepository.java`
- Modify: `src/main/java/com/dony/api/auth/dto/RegisterRequest.java`
- Modify: `src/main/java/com/dony/api/auth/AuthService.java`
- Modify: `src/main/java/com/dony/api/auth/AuthController.java`

- [ ] **Step 1 : Écrire les tests qui échouent pour AuthService**

Dans `src/test/java/com/dony/api/auth/AuthServiceTest.java`, ajouter une nouvelle classe imbriquée :

```java
@Nested
@DisplayName("register — routing par provider Firebase")
class RegisterWithProvider {

    private FirebaseToken mockToken(String signInProvider, String email) {
        FirebaseToken token = mock(FirebaseToken.class);
        Map<String, Object> firebase = Map.of("sign_in_provider", signInProvider);
        when(token.getFirebase()).thenReturn(firebase);
        when(token.getEmail()).thenReturn(email);
        return token;
    }

    @Test
    @DisplayName("provider phone — phoneNumber obligatoire")
    void phone_phoneNumberRequired() {
        FirebaseToken token = mockToken("phone", null);
        RegisterRequest req = new RegisterRequest(null, null, Set.of("SENDER"));

        assertThatThrownBy(() -> authService.register(FIREBASE_UID, token, req))
                .isInstanceOf(DonyBusinessException.class);
    }

    @Test
    @DisplayName("provider phone — succès")
    void phone_success() {
        FirebaseToken token = mockToken("phone", null);
        RegisterRequest req = new RegisterRequest(PHONE, null, Set.of("SENDER"));
        when(userRepository.findByFirebaseUid(FIREBASE_UID)).thenReturn(Optional.empty());
        when(userRepository.existsByPhoneNumber(PHONE)).thenReturn(false);
        when(userRepository.save(any())).thenAnswer(i -> {
            UserEntity u = i.getArgument(0);
            setId(u, UUID.randomUUID());
            return u;
        });

        UserResponse result = authService.register(FIREBASE_UID, token, req);

        assertThat(result).isNotNull();
        verify(userRepository).save(argThat(u -> PHONE.equals(u.getPhoneNumber())));
    }

    @Test
    @DisplayName("provider google.com — email depuis token Firebase (pas du body)")
    void google_emailFromToken() {
        FirebaseToken token = mockToken("google.com", "google@gmail.com");
        RegisterRequest req = new RegisterRequest(null, null, Set.of("SENDER"));
        when(userRepository.findByFirebaseUid(FIREBASE_UID)).thenReturn(Optional.empty());
        when(userRepository.existsByEmail("google@gmail.com")).thenReturn(false);
        when(userRepository.findByEmail("google@gmail.com")).thenReturn(Optional.empty());
        when(userRepository.save(any())).thenAnswer(i -> {
            UserEntity u = i.getArgument(0);
            setId(u, UUID.randomUUID());
            return u;
        });

        UserResponse result = authService.register(FIREBASE_UID, token, req);

        assertThat(result).isNotNull();
        verify(userRepository).save(argThat(u -> "google@gmail.com".equals(u.getEmail())));
    }

    @Test
    @DisplayName("provider custom (email OTP) — email depuis body")
    void custom_emailFromBody() {
        FirebaseToken token = mockToken("custom", null);
        RegisterRequest req = new RegisterRequest(null, "otp@example.com", Set.of("SENDER"));
        when(userRepository.findByFirebaseUid(FIREBASE_UID)).thenReturn(Optional.empty());
        when(userRepository.existsByEmail("otp@example.com")).thenReturn(false);
        when(userRepository.findByEmail("otp@example.com")).thenReturn(Optional.empty());
        when(userRepository.save(any())).thenAnswer(i -> {
            UserEntity u = i.getArgument(0);
            setId(u, UUID.randomUUID());
            return u;
        });

        UserResponse result = authService.register(FIREBASE_UID, token, req);

        assertThat(result).isNotNull();
        verify(userRepository).save(argThat(u -> "otp@example.com".equals(u.getEmail())));
    }

    @Test
    @DisplayName("provider inconnu → 422")
    void unknownProvider_422() {
        FirebaseToken token = mockToken("password", null);
        RegisterRequest req = new RegisterRequest(null, null, Set.of("SENDER"));
        when(userRepository.findByFirebaseUid(FIREBASE_UID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.register(FIREBASE_UID, token, req))
                .isInstanceOf(DonyBusinessException.class)
                .extracting(e -> ((DonyBusinessException) e).getStatus())
                .isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
    }
}
```

Lancer : `./mvnw test -Dtest=AuthServiceTest -Dspring.profiles.active=test`
Expected : FAIL (signature `register(String, FirebaseToken, RegisterRequest)` introuvable)

- [ ] **Step 2 : Corriger FirebaseTokenFilter (ligne 78)**

Dans `src/main/java/com/dony/api/auth/FirebaseTokenFilter.java`, changer la ligne 78 :

```java
// AVANT (ligne 78)
setAuthentication(uid, null, List.of());

// APRÈS
setAuthentication(uid, decoded, List.of());
```

- [ ] **Step 3 : Mettre à jour UserRepository**

Ajouter dans `src/main/java/com/dony/api/auth/UserRepository.java` :

```java
boolean existsByEmail(String email);

Optional<UserEntity> findByEmail(String email);
```

- [ ] **Step 4 : Mettre à jour RegisterRequest**

Remplacer le contenu de `src/main/java/com/dony/api/auth/dto/RegisterRequest.java` :

```java
package com.dony.api.auth.dto;

import jakarta.annotation.Nullable;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.Set;

public record RegisterRequest(

    @Nullable
    @Pattern(
        regexp = "\\+[1-9]\\d{6,14}",
        message = "Le numéro doit être au format E.164 (ex: +33612345678)"
    )
    String phoneNumber,

    @Nullable
    @Email(message = "Format email invalide")
    String email,

    @NotEmpty(message = "Au moins un rôle est requis")
    @Size(max = 2, message = "Maximum 2 rôles")
    Set<String> roles
) {}
```

- [ ] **Step 5 : Mettre à jour AuthService**

Remplacer la signature et le corps des méthodes `register` et `createUser` dans `src/main/java/com/dony/api/auth/AuthService.java` :

```java
import com.google.firebase.auth.FirebaseToken;
// ... (garder les imports existants)

@Transactional
public UserResponse register(String firebaseUid, FirebaseToken decodedToken, RegisterRequest request) {
    return userRepository.findByFirebaseUid(firebaseUid)
            .map(this::toResponse)
            .orElseGet(() -> createUser(firebaseUid, decodedToken, request));
}

private UserResponse createUser(String firebaseUid, FirebaseToken decodedToken, RegisterRequest request) {
    Set<Role> roles = parseRoles(request.roles());

    if (roles.contains(Role.ADMIN)) {
        throw new DonyBusinessException(
                HttpStatus.FORBIDDEN, "forbidden-role",
                "Forbidden Role", "Le rôle ADMIN ne peut pas être auto-attribué");
    }

    String signInProvider = decodedToken != null
            ? (String) decodedToken.getFirebase().get("sign_in_provider")
            : null;

    UserEntity user = new UserEntity();
    user.setFirebaseUid(firebaseUid);
    user.setStatus(UserStatus.ACTIVE);
    user.setKycStatus(KycStatus.NOT_STARTED);
    user.setRoles(roles);

    switch (signInProvider == null ? "" : signInProvider) {
        case "phone" -> {
            if (request.phoneNumber() == null) {
                throw new DonyBusinessException(
                        HttpStatus.UNPROCESSABLE_ENTITY, "phone-required",
                        "Phone Required", "Le numéro de téléphone est requis");
            }
            if (userRepository.existsByPhoneNumber(request.phoneNumber())) {
                throw new DonyBusinessException(
                        HttpStatus.CONFLICT, "phone-already-exists",
                        "Phone Number Already Registered", "Ce numéro est déjà associé à un compte");
            }
            user.setPhoneNumber(request.phoneNumber());
        }
        case "google.com", "apple.com" -> {
            String email = decodedToken.getEmail();
            if (email == null) {
                throw new DonyBusinessException(
                        HttpStatus.UNPROCESSABLE_ENTITY, "email-required",
                        "Email Required", "L'email est introuvable dans le token Firebase");
            }
            if (userRepository.existsByEmail(email)) {
                return toResponse(userRepository.findByEmail(email).orElseThrow());
            }
            user.setEmail(email);
        }
        case "custom" -> {
            // Email OTP — email fourni par le client, vérifié en amont par le service OTP
            if (request.email() == null) {
                throw new DonyBusinessException(
                        HttpStatus.UNPROCESSABLE_ENTITY, "email-required",
                        "Email Required", "L'adresse email est requise");
            }
            if (userRepository.existsByEmail(request.email())) {
                return toResponse(userRepository.findByEmail(request.email()).orElseThrow());
            }
            user.setEmail(request.email());
        }
        default -> throw new DonyBusinessException(
                HttpStatus.UNPROCESSABLE_ENTITY, "invalid-provider",
                "Invalid Provider", "Mode d'authentification non supporté");
    }

    UserEntity saved = userRepository.save(user);

    auditService.log(
            "USER", saved.getId(), "USER_CREATED", saved.getId(),
            Map.of("provider", String.valueOf(signInProvider), "roles", request.roles())
    );

    eventPublisher.publishEvent(new UserRegisteredEvent(saved.getId(), saved.getFirebaseUid()));

    return toResponse(saved);
}
```

- [ ] **Step 6 : Mettre à jour AuthController**

Dans `src/main/java/com/dony/api/auth/AuthController.java`, modifier la méthode `register` :

```java
import com.google.firebase.auth.FirebaseToken;
import org.springframework.security.core.Authentication;

@PostMapping("/register")
public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request) {
    String firebaseUid = requireFirebaseUid();
    Authentication auth = SecurityContextHolder.getContext().getAuthentication();
    FirebaseToken decodedToken = auth.getCredentials() instanceof FirebaseToken t ? t : null;
    return ResponseEntity.status(HttpStatus.CREATED)
            .body(authService.register(firebaseUid, decodedToken, request));
}
```

- [ ] **Step 7 : Lancer les tests**

```bash
./mvnw test -Dtest=AuthServiceTest -Dspring.profiles.active=test
```

Expected : tous PASS

- [ ] **Step 8 : Lancer tous les tests**

```bash
./mvnw test -Dspring.profiles.active=test
```

Expected : tous PASS (0 rouge)

- [ ] **Step 9 : Commit**

```bash
git add src/main/java/com/dony/api/auth/FirebaseTokenFilter.java \
        src/main/java/com/dony/api/auth/UserRepository.java \
        src/main/java/com/dony/api/auth/dto/RegisterRequest.java \
        src/main/java/com/dony/api/auth/AuthService.java \
        src/main/java/com/dony/api/auth/AuthController.java \
        src/test/java/com/dony/api/auth/AuthServiceTest.java
git commit -m "feat(auth): register multi-provider (phone/google/apple/custom email-OTP)"
```

---

### Task 7 : Couverture ≥ 90 % — vérification finale

**Files:**
- Verify: tous les fichiers créés/modifiés ci-dessus

- [ ] **Step 1 : Lancer tous les tests**

```bash
cd dony-back
./mvnw test -Dspring.profiles.active=test
```

Expected : 0 test rouge.

- [ ] **Step 2 : Générer et vérifier le rapport JaCoCo**

```bash
./mvnw test jacoco:report -Dspring.profiles.active=test
```

Ouvrir `target/site/jacoco/index.html` et vérifier :
- `com.dony.api.emailotp` ≥ 90 % instruction coverage
- `com.dony.api.auth` ≥ 90 % (doit rester ≥ 90 % après les modifications)

Si la couverture est < 90 % sur un package, ajouter des tests dans les fichiers de test correspondants.

- [ ] **Step 3 : Cas manquants à couvrir si nécessaire**

Tests supplémentaires à ajouter si la couverture est insuffisante :

**EmailOtpService :**
- `sendOtp` : exactement 2 envois dans la fenêtre → pas de rate-limit (accepté)
- `verifyOtp` : `firebaseAuth == null` → retourne `null` sans exception

**AuthService :**
- `register` → user existant (idempotent) — déjà couvert par tests existants
- `createUser` → provider `apple.com` (même logique que `google.com`)

**EmailOtpController :**
- `send` : body manquant → 400
- `verify` : code trop court → 422

- [ ] **Step 4 : Commit final si des tests ont été ajoutés**

```bash
git add src/test/
git commit -m "test(emailotp,auth): couverture ≥ 90 % — cas supplémentaires"
```

---

## Checklist de validation finale

- [ ] `./mvnw test` → 0 rouge
- [ ] `./mvnw test jacoco:report` → `com.dony.api.emailotp` ≥ 90 %, `com.dony.api.auth` ≥ 90 %
- [ ] `POST /auth/email-otp/send` retourne `{ "expiresAt": "..." }`
- [ ] `POST /auth/email-otp/verify` retourne `{ "customToken": "..." }` en prod (null accepté en test)
- [ ] `POST /auth/register` accepte `phoneNumber` pour provider `phone`
- [ ] `POST /auth/register` accepte `email` pour providers `google.com`, `apple.com`, `custom`
- [ ] `FirebaseTokenFilter` ligne 78 : `decoded` (pas `null`) pour les nouveaux utilisateurs
- [ ] Aucune migration existante modifiée — V88 uniquement
- [ ] `SecurityConfig` : bean `PasswordEncoder` ajouté
- [ ] `FirebaseConfig` : bean `FirebaseAuth` ajouté (null-safe en test)
