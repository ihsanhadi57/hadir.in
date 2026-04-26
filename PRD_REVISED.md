# PRODUCT REQUIREMENTS DOCUMENT (PRD) - Hadir.in (Revised)

## 1. Executive Summary
Hadir.in is a smart attendance and ticketing system designed for flexibility. It supports two main attendance flows:
1.  **Staffed Flow**: Committee members use a mobile app to scan participant tickets.
2.  **Self-Service Flow**: Participants check-in via a mobile-friendly web interface using photo and GPS validation, eliminating the need for staff or app downloads.

## 2. User Roles & Workflows

### 2.1 Organizer (Mobile App)
*   **Goal**: Event management and real-time monitoring.
*   **Features**:
    *   Authentication (JWT).
    *   Create events with geofence boundaries (coordinates).
    *   Manage participant database (Manual entry / CSV Bulk Upload).
    *   Design e-tickets.
    *   **Dashboard**: Real-time stats on attendance (Total, Hadir, Belum Datang).
    *   **Email Blast**: Send e-tickets with unique QR codes to participants.

### 2.2 Committee (Mobile App)
*   **Goal**: Rapid validation of pre-registered participants.
*   **Features**:
    *   **QR Scanner**: Scan participant e-tickets.
    *   **Validation**: Real-time check against database (Valid, Already Scanned, Invalid).
    *   *Note: Committee members do not need to take photos or record GPS, as their physical presence at the gate is the validation.*

### 2.3 Participant (Web Interface - UX Focused)
*   **Goal**: Hassle-free attendance without downloading an app.
*   **Workflows**:
    *   **A. Staffed Event**: Receive e-ticket via email, show QR code to Committee for scanning.
    *   **B. Self Check-In**: Scan a venue QR code or visit a link. Provide details (Name/Email), take a selfie as proof, and share GPS location to validate they are at the event venue.

## 3. Functional Requirements

### 3.1 Core Systems
*   **QR Ticketing**: Unique UUID-based tickets generated per participant.
*   **Geofencing**: Backend validation to compare participant's GPS with event coordinates during self-check-in.
*   **Evidence System**: Photo capture requirement for self-check-in to prevent proxy attendance.
*   **Real-Time Data**: Dashboard must update instantly when check-ins occur (Socket.io).
*   **Payment & Monetization (Upcoming)**: Integration with payment gateways (Midtrans/Doku) for paid event ticketing.

### 3.2 Communication & UX
*   **Email Engine**: Integration with Mailketing for reliable delivery of e-tickets.
*   **Gen Z Aesthetic**: Vibrant UI/UX, casual language, and minimal friction (no app required for participants).

## 4. Technical Stack
*   **Frontend**: Flutter (Mobile App & Web).
*   **Backend**: Node.js + Express.js.
*   **Database**: PostgreSQL / MySQL with Prisma ORM.
*   **Real-Time**: Socket.io (Implemented).
*   **Cloud Services**: Cloudinary (Image storage), Mailketing (Email).

## 5. Implementation Roadmap

### Phase 1: Core Stability (Current)
*   [x] JWT Authentication.
*   [x] Participant Management (Bulk/Manual).
*   [x] E-Ticket Design & Generation.
*   [x] QR Scanner for Committee.
*   [x] Self Check-In Web Interface with Photo & GPS.

### Phase 2: Engagement & Real-Time (Completed)
*   [x] **Mailketing Email Blast**: Integration with Mailketing for reliable e-ticket delivery.
*   [x] **Socket.io Integration**: Real-time event check-in counters connected to the Flutter Dashboard.

### Phase 3: Monetization & Ticketing (Next Steps)
*   [ ] **Payment Gateway Integration**: Integration with Midtrans and/or Doku for paid ticketing (Currently pending business review).
*   [ ] **Paid Ticket Checkout Flow**: End-to-end checkout experience for participants buying premium tickets.

---

> [!NOTE]
> The primary focus is now on making the **Self Check-In** as robust as possible for un-staffed events (like lectures or community meetups) while keeping the **Staffed Scan** fast for large events.
