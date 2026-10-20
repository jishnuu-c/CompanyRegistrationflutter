# Spring Boot Authentication & Security Specification

This document details the backend REST API contracts, security architecture, and migration guide to connect the Spring Boot backend with the Flutter mobile client (`company_reg_flutter`).

---

## 1. Architecture Overview

```
 ┌─────────────────────────────────────────────────────────┐
 │                   Flutter Mobile App                    │
 │                                                         │
 │  ┌───────────────────────────────────────────────────┐  │
 │  │              Central AuthService                  │  │
 │  └─────────┬───────────────────────────┬─────────────┘  │
 │            │ (Active Provider)         │                │
 │  ┌─────────▼──────────────┐  ┌─────────▼─────────────┐  │
 │  │      DemoAuthProvider  │  │    ApiAuthProvider    │  │
 │  │  (Local in-memory,     │  │  (Live HTTP to        │  │
 │  │   Simulated OTP &      │  │   Spring Boot Server) │  │
 │  │   Native Biometrics)   │  │                       │  │
 │  └────────────────────────┘  └───────────┬───────────┘  │
 └──────────────────────────────────────────┼──────────────┘
                                            │ HTTPS / JSON
                                ┌───────────▼───────────┐
                                │   Spring Boot Backend │
                                │ (Spring Security 6.x) │
                                │   JJWT 0.12.x Token   │
                                └───────────────────────┘
```

The Flutter application defaults to **DEMO MODE**. When the Spring Boot backend is ready, switch mode by tapping the **DEMO MODE ACTIVE** indicator on the Login screen or calling `AuthService().setAuthMode(AuthMode.api)`.

---

## 2. API Endpoints Contract

### Base URL: `http://<host>:8080/api/auth`

---

### 2.1. Password Login
- **Endpoint**: `POST /api/auth/login`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Request Body**:
```json
{
  "usernameOrEmail": "SuperAdmin",
  "password": "companyAdmin"
}
```
- **Response `200 OK`**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "username": "SuperAdmin",
  "email": "admin@corpregistry.com",
  "fullName": "System Administrator",
  "role": "ROLE_ADMIN",
  "expiresIn": 86400
}
```
- **Error Responses**:
  - `401 Unauthorized`: `{"message": "Invalid username/email or password."}`
  - `403 Forbidden`: `{"message": "Account disabled or pending review."}`

---

### 2.2. User Registration
- **Endpoint**: `POST /api/auth/register`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Request Body**:
```json
{
  "fullName": "Jane Doe",
  "username": "janedoe",
  "email": "jane@example.com",
  "password": "SecurePassword123"
}
```
- **Response `200 OK` or `201 Created`**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "username": "janedoe",
  "email": "jane@example.com",
  "fullName": "Jane Doe",
  "role": "ROLE_USER",
  "expiresIn": 86400
}
```
- **Error Responses**:
  - `400 Bad Request`: `{"message": "Username or email is already taken."}`

---

### 2.3. Request OTP
- **Endpoint**: `POST /api/auth/otp/request`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Request Body**:
```json
{
  "identifier": "9876543210"
}
```
*Note: `identifier` can be either an E.164 / 10-digit mobile phone number or an email address.*
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "OTP sent successfully to 9876543210",
  "expiresInSeconds": 120,
  "cooldownSeconds": 30
}
```
- **Error Responses**:
  - `429 Too Many Requests`: `{"message": "Please wait 25 seconds before requesting another OTP."}`
  - `400 Bad Request`: `{"message": "Invalid phone number or email format."}`

---

### 2.4. Verify OTP
- **Endpoint**: `POST /api/auth/otp/verify`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Request Body**:
```json
{
  "identifier": "9876543210",
  "otp": "481923"
}
```
- **Response `200 OK`**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "username": "SuperAdmin",
  "email": "admin@corpregistry.com",
  "fullName": "System Administrator",
  "role": "ROLE_ADMIN",
  "expiresIn": 86400
}
```
- **Error Responses**:
  - `400 Bad Request`: `{"message": "Incorrect OTP code. 2 attempts remaining."}`
  - `410 Gone`: `{"message": "OTP code has expired. Please request a new code."}`
  - `429 Too Many Requests`: `{"message": "Maximum verification attempts exceeded."}`

---

### 2.5. Fetch Current User Profile
- **Endpoint**: `GET /api/auth/me`
- **Headers**:
  - `Authorization: Bearer <token>`
  - `Accept: application/json`
- **Response `200 OK`**:
```json
{
  "id": 1,
  "username": "SuperAdmin",
  "email": "admin@corpregistry.com",
  "fullName": "System Administrator",
  "role": "ROLE_ADMIN"
}
```
- **Error Responses**:
  - `401 Unauthorized`: Expired or invalid token.

---

### 2.6. Biometric Credential Registration & Authentication
- **Endpoint**: `POST /api/auth/biometrics/register`
- **Headers**: `Authorization: Bearer <token>`
- **Request Body**:
```json
{
  "username": "SuperAdmin"
}
```
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Biometric device link registered."
}
```

- **Endpoint**: `POST /api/auth/biometrics/authenticate`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Request Body**:
```json
{
  "username": "SuperAdmin"
}
```
- **Response `200 OK`**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "username": "SuperAdmin",
  "email": "admin@corpregistry.com",
  "fullName": "System Administrator",
  "role": "ROLE_ADMIN",
  "expiresIn": 86400
}
```

---

## 3. Recommended Spring Boot Controller Template

```java
package com.example.companyreg.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        // Authenticate via AuthenticationManager, return JWT AuthResponse
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/otp/request")
    public ResponseEntity<?> requestOtp(@RequestBody Map<String, String> body) {
        String identifier = body.get("identifier");
        return ResponseEntity.ok(otpService.generateAndSend(identifier));
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<?> verifyOtp(@RequestBody Map<String, String> body) {
        String identifier = body.get("identifier");
        String otp = body.get("otp");
        return ResponseEntity.ok(otpService.verify(identifier, otp));
    }

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@RequestHeader("Authorization") String authHeader) {
        return ResponseEntity.ok(authService.getCurrentUserProfile(authHeader));
    }
}
```

---

## 4. Switching Modes in Flutter

1. **In UI**: Tap the **DEMO MODE ACTIVE** badge at the top of the Login Screen. Select **Switch to Spring Boot API Mode**.
2. **Programmatically**:
   ```dart
   await AuthService().setAuthMode(AuthMode.api);
   ```
   Or to return to Demo mode:
   ```dart
   await AuthService().setAuthMode(AuthMode.demo);
   ```
