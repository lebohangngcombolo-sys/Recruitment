# Postman Testing Guide: Enrollment & Profile APIs

This guide helps you test that **all enrollment form fields** are saved on the backend and returned on the profile. You can test each section (Personal Info, Education, Skills, Work Experience) and verify data persists after refresh or logout.

---

## What is Postman?

**Postman** is a tool that sends HTTP requests (like a browser or app) and shows you the server’s response. You choose the **method** (GET, POST, etc.), **URL**, **headers** (e.g. auth), and **body** (the data you send). The server’s reply appears in the **Response** panel. No frontend is needed—you’re testing the backend directly.

---

## Base URL & Endpoints

Assume the server runs at:

- **Base URL:** `http://127.0.0.1:5000`  
  (Change to your deployed URL if different.)

| What you do              | Method | Endpoint                                | Purpose                          |
|--------------------------|--------|-----------------------------------------|----------------------------------|
| Log in                   | POST   | `/api/auth/login`                       | Get JWT token for later requests |
| Submit enrollment        | POST   | `/api/candidate/enrollment`             | Save all candidate fields        |
| Get current user + profile | GET  | `/api/auth/me`                          | User + candidate profile (app uses this) |
| Get candidate profile   | GET    | `/api/candidate/profile`                | Full profile (user + candidate)  |
| Update candidate profile| PUT    | `/api/candidate/profile`                | Change profile fields            |
| Upload profile picture  | POST   | `/api/candidate/upload_profile_picture` | Set profile photo (form-data: image) |
| Update user settings    | PUT    | `/api/candidate/settings`               | Update user settings (e.g. dark_mode) |

---

## Step 1: Get a JWT token (login)

You must be logged in as a **candidate** to call enrollment and profile.

1. In Postman, create a **new request**.
2. Set **Method** to **POST**.
3. Set **URL** to: `http://127.0.0.1:5000/api/auth/login`.
4. **Headers:** Add `Content-Type` = `application/json` (or use **Body → raw → JSON**, which often sets it for you).
5. Open the **Body** tab → choose **raw** → select **JSON** in the dropdown → paste:

```json
{
  "email": "your-candidate@example.com",
  "password": "your-password"
}
```

6. Click **Send**.
   - If you get **415 Unsupported Media Type**: set the **Headers** tab → add `Content-Type` = `application/json`.

**What to check:**  
- Status should be **200**.  
- In the **Response** body you should see something like:

```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": { ... }
}
```

**Simple explanation:** The server checks your email and password and returns an **access_token** (JWT). You will send this token in the next requests so the server knows who you are.

---

## Step 2: Save the token for later requests

1. In the **Tests** tab of the same login request, paste:

```javascript
var json = pm.response.json();
if (json.access_token) {
    pm.environment.set("auth_token", json.access_token);
}
```

2. Click **Send** again.  
   (If you use **Environment** in Postman, the token is stored in `auth_token`.)

**Simple explanation:** This script runs after the response. It takes the token from the JSON and saves it into a variable so you don’t have to copy-paste it into every request.

---

## Step 3: Send enrollment (all fields)

This request saves **all** enrollment fields the backend expects. You can use it to confirm every field is stored.

1. **New request** → **POST** → `http://127.0.0.1:5000/api/candidate/enrollment`.
2. **Headers:**
   - Key: `Content-Type` → Value: `application/json`
   - Key: `Authorization` → Value: `Bearer {{auth_token}}`  
     (If you didn’t set an environment variable, type `Bearer ` and then paste the token.)
3. **Body** → **raw** → **JSON**.
4. Paste the JSON below (then click **Send**).

### Full enrollment JSON (all sections)

```json
{
  "full_name": "Test User",
  "phone": "0812345678",
  "dob": "1995-06-15",
  "address": "123 Test Street, City",
  "gender": "Other",
  "linkedin": "https://linkedin.com/in/testuser",

  "education": [
    {
      "level": "Bachelor",
      "institution": "Test University",
      "graduation_year": "2019"
    }
  ],

  "skills": ["Python", "SQL", "Problem-solving", "Agile"],
  "certifications": ["AWS Certified", "Scrum Master"],
  "languages": ["English", "Zulu"],

  "work_experience": [
    {
      "description": "Developed and maintained web applications.",
      "company": "Test Company Pty Ltd",
      "position": "Junior Developer"
    }
  ]
}
```

**What to check:**  
- Status **200**.  
- Response should include something like `"message": "Enrollment completed successfully"` and `"saved_fields"` listing the fields that were saved.

**Simple explanation:** The server reads this JSON and writes each field into the database (candidate row). Lists like `education` and `work_experience` are stored as JSON in the same shape you send.

---

## Step 4: Get profile and verify data

After enrollment, the same data should appear when you fetch the profile (and after refresh/logout, as long as you log in again).

1. **New request** → **GET** → `http://127.0.0.1:5000/api/candidate/profile`.
2. **Headers:**  
   - `Authorization`: `Bearer {{auth_token}}`
3. **Send** (no body for GET).

**What to check:**  
- Status **200**.  
- In `data.candidate` you should see all the fields you sent:
   - **Personal:** `full_name`, `phone`, `dob`, `address`, `gender`, `linkedin`
   - **Education:** `education` (array of objects with `level`, `institution`, `graduation_year`)
   - **Skills:** `skills` (array of strings)
   - **Certifications:** `certifications` (array)
   - **Languages:** `languages` (array)
   - **Work experience:** `work_experience` (array of objects with `description`, `company`, `position`)

**Simple explanation:** GET does not send a body; it only asks for data. The server uses the JWT to find your user and candidate row and returns the stored profile. If you see all fields here, the backend is saving and returning them correctly.

---

## Backend field reference (enrollment form → API)

These are the fields the backend accepts and stores. Use them to test **one section at a time** in Postman if you want.

### Personal information

| Key        | Type   | Example / notes                    |
|-----------|--------|------------------------------------|
| `full_name` | string | `"Jane Doe"`                       |
| `phone`     | string | `"0812345678"`                     |
| `dob`       | string | `"1995-06-15"` (YYYY-MM-DD)        |
| `address`   | string | `"123 Street, City"`               |
| `gender`    | string | `"Male"`, `"Female"`, `"Other"`, etc. |
| `linkedin`  | string | `"https://linkedin.com/in/..."`    |

Optional (schema allows; add if you use them):  
`bio`, `title`, `location`, `nationality`, `id_number`, `github`, `portfolio`, `cover_letter`, `profile_picture`, `cv_url`.

### Education

| Key          | Type  | Shape / example                                  |
|-------------|-------|--------------------------------------------------|
| `education` | array | List of objects: `level`, `institution`, `graduation_year` |

Example:

```json
"education": [
  { "level": "Bachelor", "institution": "University of X", "graduation_year": "2019" }
]
```

### Skills & certifications & languages

| Key              | Type  | Example                          |
|------------------|-------|----------------------------------|
| `skills`         | array | `["Python", "SQL", "Agile"]`    |
| `certifications` | array | `["AWS Certified", "Scrum"]`    |
| `languages`      | array | `["English", "Zulu"]`           |

Backend accepts arrays of strings (or, for certifications, the schema allows list of dicts; strings are fine for testing).

### Work experience

| Key               | Type  | Shape / example                                           |
|-------------------|-------|-----------------------------------------------------------|
| `work_experience` | array | List of objects: `description`, `company`, `position`   |

Example:

```json
"work_experience": [
  {
    "description": "Responsibilities and achievements.",
    "company": "Company Name (Pty) Ltd",
    "position": "Job Title"
  }
]
```

---

## Testing one section at a time

To isolate issues (e.g. “is personal info saved?” or “is work experience saved?”):

1. **Personal only:**  
   POST to `/api/candidate/enrollment` with **only** personal keys (`full_name`, `phone`, `dob`, `address`, `gender`, `linkedin`).  
   Then GET `/api/candidate/profile` and check `data.candidate` for those keys.

2. **Add education:**  
   Send the same personal fields **plus** `education` (one or more objects).  
   GET profile again and check `data.candidate.education`.

3. **Add skills / certifications / languages:**  
   Add `skills`, `certifications`, `languages` to the body.  
   GET profile and check those arrays.

4. **Add work experience:**  
   Add `work_experience` (one or more objects).  
   GET profile and check `data.candidate.work_experience`.

Use the same JWT for all requests (same login). After each POST, a GET profile shows what the backend has stored.

---

## Optional: Get profile via `/api/auth/me`

`GET /api/auth/me` returns the current user **and** (if the user is a candidate) the full candidate profile.

1. **GET** → `http://127.0.0.1:5000/api/auth/me`
2. **Header:** `Authorization`: `Bearer {{auth_token}}`
3. **Send**

In the response, look for `candidate_profile`. It should contain the same fields as `GET /api/candidate/profile` → `data.candidate`. This is the same data the frontend can use for the Profile Overview after login, refresh, or logout-and-login.

---

## Part 2: Testing user profile

These steps let you test the **user profile** APIs: get profile data (what the app shows on “Profile Overview”) and update it. You use the same JWT from login.

### Profile endpoints (overview)

| Action              | Method | Endpoint                          | Auth        |
|---------------------|--------|-----------------------------------|-------------|
| Get current user + profile | GET    | `/api/auth/me`                    | Bearer JWT  |
| Get candidate profile     | GET    | `/api/candidate/profile`          | Bearer JWT  |
| Update candidate profile | PUT    | `/api/candidate/profile`          | Bearer JWT  |
| Upload profile picture   | POST   | `/api/candidate/upload_profile_picture` | Bearer JWT  |
| Update user settings     | PUT    | `/api/candidate/settings`         | Bearer JWT  |

**Simple explanation:** All of these need the **Authorization** header so the server knows which user you are. Use the token you got from login.

---

### Step A: Get current user and profile (GET /api/auth/me)

This is what the app often uses after login to show the user and their profile (e.g. Profile Overview).

1. **New request** → **GET** → `http://127.0.0.1:5000/api/auth/me`.
2. **Headers:** `Authorization` = `Bearer {{auth_token}}` (or paste your token after `Bearer `).
3. **Send** (no body).

**What to check:**

- Status **200**.
- Body includes:
  - **`user`** – id, email, role, enrollment_completed, profile, etc.
  - **`candidate_profile`** – full candidate object (personal info, education, skills, work_experience, etc.) if the user is a candidate and has one.
  - **`dashboard`** – where the app should redirect.

If `candidate_profile` is present, that’s the data that should appear on the Profile Overview screen. If it’s missing but the user is a candidate, they may not have completed enrollment yet.

---

### Step B: Get candidate profile only (GET /api/candidate/profile)

Returns the full candidate record (and user) in a different shape. Useful to confirm exactly what the backend stores.

1. **GET** → `http://127.0.0.1:5000/api/candidate/profile`.
2. **Headers:** `Authorization` = `Bearer {{auth_token}}`.
3. **Send**.

**What to check:**

- Status **200**.
- Body shape: `{ "success": true, "data": { "user": { ... }, "candidate": { ... } } }`.
- **`data.candidate`** should have all profile fields: full_name, phone, dob, address, gender, linkedin, education, skills, certifications, languages, work_experience, etc.

**Simple explanation:** This endpoint loads the candidate row for the logged-in user. If you get **404** or “Candidate not found”, that user has no candidate record yet (complete enrollment first).

---

### Step C: Update candidate profile (PUT /api/candidate/profile)

Use this to change profile data and confirm it persists (then re-call GET to verify).

1. **New request** → **PUT** → `http://127.0.0.1:5000/api/candidate/profile`.
2. **Headers:**
   - `Authorization` = `Bearer {{auth_token}}`
   - `Content-Type` = `application/json`
3. **Body** → **raw** → **JSON**. Send only the keys you want to change. Example:

```json
{
  "full_name": "Updated Name",
  "phone": "0812345678",
  "address": "New address here",
  "linkedin": "https://linkedin.com/in/updated",
  "education": [
    {
      "level": "Bachelor",
      "institution": "New University",
      "graduation_year": "2020"
    }
  ],
  "skills": ["Python", "SQL", "New Skill"],
  "work_experience": [
    {
      "description": "Updated role description.",
      "company": "New Company",
      "position": "Senior Developer"
    }
  ]
}
```

4. **Send**.

**What to check:**

- Status **200**.
- Body: `{ "success": true, "message": "Profile updated successfully", "data": { "user": {...}, "candidate": {...} } }`.
- **`data.candidate`** should reflect your updates.

**Validation rules (backend):**

- **phone:** If provided, must be exactly 10 digits (numbers only).
- **dob:** If provided, must be `YYYY-MM-DD` (e.g. `1995-06-15`).
- **id_number:** If provided, must be exactly 13 digits.
- **email:** Cannot be updated via this endpoint (ignored if sent).

If you send an invalid value (e.g. phone with letters), you’ll get **400** with a message explaining the rule.

---

### Step D (optional): Upload profile picture

1. **POST** → `http://127.0.0.1:5000/api/candidate/upload_profile_picture`.
2. **Headers:** `Authorization` = `Bearer {{auth_token}}`.
3. **Body** → **form-data** (not raw JSON).
   - Key: `image` (type: File).
   - Value: choose an image file (e.g. PNG, JPG, JPEG, WEBP).
4. **Send**.

**What to check:** Status **200** and a response with `data.profile_picture` (URL). Then GET profile again; the candidate’s `profile_picture` field should be set.

---

### Step E (optional): Update user settings

1. **PUT** → `http://127.0.0.1:5000/api/candidate/settings`.
2. **Headers:** `Authorization` = `Bearer {{auth_token}}`, `Content-Type` = `application/json`.
3. **Body** → **raw** → **JSON**, e.g. `{ "dark_mode": true }` or any key-value pairs you want stored under user settings.
4. **Send**.

**What to check:** Status **200**. Settings are merged with existing ones. You can confirm by calling GET `/api/auth/me` and checking the user’s settings (if the API exposes them there) or your app’s behaviour.

---

### Profile testing checklist

- [ ] **GET /api/auth/me** returns 200 with `user` and (for candidates) `candidate_profile`.
- [ ] **GET /api/candidate/profile** returns 200 with `data.candidate` containing personal info, education, skills, work_experience.
- [ ] **PUT /api/candidate/profile** with a few fields returns 200 and `data.candidate` shows the updates.
- [ ] After PUT, **GET /api/candidate/profile** or **GET /api/auth/me** again shows the updated data (persistent).
- [ ] Invalid phone/dob/id_number in PUT returns 400 with a clear message.
- [ ] (Optional) Upload profile picture and confirm `profile_picture` in GET profile.

---

## Quick checklist

- [ ] Login (POST `/api/auth/login`) returns `access_token`.
- [ ] Token is set (e.g. in environment as `auth_token`).
- [ ] POST `/api/candidate/enrollment` with full JSON returns 200 and `saved_fields`.
- [ ] GET `/api/candidate/profile` returns 200 and `data.candidate` with:
  - [ ] Personal: `full_name`, `phone`, `dob`, `address`, `gender`, `linkedin`
  - [ ] `education` (array of objects)
  - [ ] `skills`, `certifications`, `languages` (arrays)
  - [ ] `work_experience` (array of objects)
- [ ] After closing Postman and opening again (or “refresh”), login again and GET profile: same data appears (persistent).

If any field is missing in the GET response but you sent it in POST, the issue is on the backend (saving or serialization). If all fields appear here but not in the app UI, the issue is on the frontend (not reading or displaying them).
