# Authentication System Documentation

This document describes the authentication system implemented for the Sonde backend.

## Overview

The authentication system provides:
- User registration with email/username
- Secure password hashing with bcrypt
- JWT-based authentication with access and refresh tokens
- Session management with device tracking
- Logout functionality (single device and all devices)

## API Endpoints

### Base URL
```
http://localhost:8000/api/v1/auth
```

### 1. Register User
```http
POST /api/v1/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "username": "optional_username",
  "full_name": "Optional Full Name"
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "optional_username",
  "full_name": "Optional Full Name",
  "is_active": true,
  "is_superuser": false,
  "is_verified": false,
  "avatar_url": null,
  "created_at": "2024-01-01T00:00:00"
}
```

### 2. Login
```http
POST /api/v1/auth/login
```

**Request Body:**
```json
{
  "email_or_username": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

### 3. Refresh Token
```http
POST /api/v1/auth/refresh
```

**Request Body:**
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

### 4. Get Current User
```http
GET /api/v1/auth/me
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "optional_username",
  "full_name": "Optional Full Name",
  "is_active": true,
  "is_superuser": false,
  "is_verified": false,
  "avatar_url": null,
  "created_at": "2024-01-01T00:00:00"
}
```

### 5. Logout
```http
POST /api/v1/auth/logout
Authorization: Bearer <access_token>
```

**Request Body (Optional):**
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response (200 OK):**
```json
{
  "message": "Successfully logged out"
}
```

### 6. Logout from All Devices
```http
POST /api/v1/auth/logout-all
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "message": "Successfully logged out from all devices"
}
```

## Security Features

### Password Security
- Passwords are hashed using bcrypt
- Minimum password length: 8 characters
- Password strength validation

### JWT Tokens
- **Access Token**:
  - Expiry: 30 minutes (configurable)
  - Used for accessing protected endpoints
- **Refresh Token**:
  - Expiry: 7 days (configurable)
  - Used to obtain new access tokens
  - Stored in database for session management

### Session Management
- Tracks active sessions per user
- Stores device information (IP, User Agent)
- Automatic cleanup of expired sessions
- Support for logout from specific devices or all devices

### Error Handling
- Custom exception types for different error scenarios
- Proper HTTP status codes
- Detailed error messages (in development mode)

## Database Schema

### Users Table
```sql
users
- id (Integer, Primary Key)
- email (String, Unique)
- username (String, Optional, Unique)
- full_name (String, Optional)
- hashed_password (String)
- status (String: active/inactive/suspended)
- is_superuser (Boolean)
- is_verified (Boolean)
- last_login_at (DateTime)
- settings (JSON)
- preferences (JSON)
- api_key (String, Optional, Unique)
- created_at (DateTime)
- updated_at (DateTime)
```

### User Sessions Table
```sql
user_sessions
- id (Integer, Primary Key)
- user_id (Integer, Foreign Key)
- session_token (String, Unique)
- refresh_token (String, Unique, Optional)
- device_info (JSON, Optional)
- ip_address (String)
- user_agent (Text)
- expires_at (DateTime)
- last_activity_at (DateTime)
- is_active (Boolean)
- created_at (DateTime)
```

## Configuration

Authentication settings in `app/core/config.py`:

```python
# JWT Configuration
ACCESS_TOKEN_EXPIRE_MINUTES = 30  # Access token expiry
REFRESH_TOKEN_EXPIRE_DAYS = 7      # Refresh token expiry
ALGORITHM = "HS256"                # JWT algorithm
SECRET_KEY = None                  # Generated dynamically
```

## Testing

Run the authentication tests:

### Using Python Script
```bash
cd backend
uv run python test_auth_endpoints.py
```

### Using pytest
```bash
cd backend
uv run pytest app/domains/user/tests/test_auth.py -v
```

### Using curl (Linux/Mac)
```bash
cd backend
chmod +x test_auth_curl.sh
./test_auth_curl.sh
```

### Using curl (Windows)
```bash
cd backend
test_auth.bat
```

## Integration with Frontend

The frontend should:

1. **Registration**:
   - Collect email, password, optional username/full name
   - Handle validation errors
   - Store user data on successful registration

2. **Login**:
   - Collect email/username and password
   - Store access and refresh tokens securely
   - Redirect to dashboard on success

3. **Token Management**:
   - Include access token in Authorization header
   - Refresh token before expiry
   - Handle token refresh failures (re-login required)

4. **Logout**:
   - Send logout request with refresh token
   - Clear stored tokens
   - Redirect to login page

5. **Protected Routes**:
   - Check for valid access token
   - Redirect to login if token missing/invalid
   - Handle API 401 responses

## Best Practices

1. **Frontend**:
   - Use secure storage for tokens (e.g., httpOnly cookies or secure storage API)
   - Implement automatic token refresh
   - Handle network errors gracefully

2. **Backend**:
   - Always validate tokens on protected endpoints
   - Use HTTPS in production
   - Implement rate limiting for auth endpoints
   - Monitor for suspicious login patterns

3. **Security**:
   - Never expose refresh tokens to JavaScript if using cookies
   - Implement CORS properly
   - Consider implementing 2FA for sensitive operations
   - Log authentication events for auditing

## Troubleshooting

### Common Issues

1. **"Token has expired"**:
   - Refresh the access token using the refresh token
   - If refresh token also expired, user must log in again

2. **"Invalid credentials"**:
   - Check email/username and password
   - Ensure user account is active

3. **"Could not validate credentials"**:
   - Check token format
   - Ensure token is not tampered with
   - Verify SECRET_KEY is consistent

4. **Registration fails with "Email already registered"**:
   - User with this email already exists
   - Implement password reset if user forgot credentials

## Future Enhancements

1. **Email Verification**:
   - Send verification email on registration
   - Require verification for full account access

2. **Password Reset**:
   - Implement password reset via email
   - Use secure, time-limited reset tokens

3. **Multi-Factor Authentication (2FA)**:
   - Support for TOTP (Time-based One-Time Password)
   - SMS or email verification

4. **OAuth2 Integration**:
   - Login with Google, GitHub, etc.
   - Link external accounts to existing users

5. **Advanced Session Management**:
   - View active sessions
   - Revoke specific sessions
   - Device trust management