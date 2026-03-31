# Requirements Document

## Introduction

Temple Community is a temple-wise community chat feature for the Temple Yatra Flutter app.
It provides a WhatsApp-like messaging experience scoped to individual temples, allowing
pilgrims, locals, and admins to communicate, share tips, and receive important alerts.

The MVP uses local/mock persistence (SharedPreferences or in-memory) with an architecture
designed for seamless future migration to a real-time backend. No authentication system
or real-time sync is required in Phase 1.

---

## Glossary

- **Community_Screen**: The top-level screen listing all temple community channels.
- **Chat_Screen**: The per-temple chat screen showing messages and an input bar.
- **Message**: A single text entry with sender username, timestamp, role badge, and optional pinned state.
- **Pilgrim**: A user role representing a visiting devotee. Default role in MVP.
- **Local**: A user role representing a resident or regular visitor of the temple area.
- **Admin**: A user role with elevated privileges; can pin and delete messages.
- **Pinned_Message**: A message promoted to a sticky banner at the top of the Chat_Screen.
- **Mock_User**: A locally stored user identity (username + role) used in the absence of an auth system.
- **Community_Repository**: The data-access layer abstracting local persistence from the rest of the app.
- **Notification_Badge**: A visual indicator on a temple channel showing unread message count.
- **Media_Placeholder**: A non-functional UI element representing future image/video attachment support.

---

## Requirements

### Requirement 1: Temple Channel List

**User Story:** As a pilgrim, I want to see a list of all temple community channels, so that I can choose which temple's community to join and read.

#### Acceptance Criteria

1. THE Community_Screen SHALL display one channel entry per temple present in the existing `allTemples` data source.
2. WHEN the Community_Screen is opened, THE Community_Screen SHALL render each channel entry with the temple name, a temple icon, and a Notification_Badge showing the unread message count.
3. WHEN a channel has zero unread messages, THE Community_Screen SHALL hide the Notification_Badge for that channel.
4. WHEN a user taps a channel entry, THE Community_Screen SHALL navigate to the Chat_Screen for the selected temple.
5. THE Community_Screen SHALL be accessible from the app's main navigation without modifying any existing working screen.

---

### Requirement 2: Per-Temple Chat Screen

**User Story:** As a pilgrim, I want to read and send messages in a temple's community chat, so that I can share tips and get information from other visitors.

#### Acceptance Criteria

1. WHEN the Chat_Screen is opened for a temple, THE Chat_Screen SHALL display all stored messages for that temple in chronological order, oldest at the top.
2. THE Chat_Screen SHALL render each message with the sender's username, role badge (Pilgrim / Local / Admin), message text, and a formatted timestamp (HH:mm, dd MMM).
3. WHEN the message list exceeds the visible area, THE Chat_Screen SHALL auto-scroll to the most recent message on first load.
4. WHEN a Pinned_Message exists for the temple, THE Chat_Screen SHALL display it in a sticky banner at the top of the message list, above all other messages.
5. WHEN there are no messages for a temple, THE Chat_Screen SHALL display an empty-state prompt encouraging the user to send the first message.
6. THE Chat_Screen SHALL provide a text input field and a send button styled consistent with the app's existing Material 3 theme.

---

### Requirement 3: Sending Messages

**User Story:** As a pilgrim, I want to type and send a text message to a temple community, so that I can contribute to the conversation.

#### Acceptance Criteria

1. WHEN the user taps the send button with non-empty input text, THE Chat_Screen SHALL append a new Message to the temple's message list with the Mock_User's username, role, current device timestamp, and the entered text.
2. WHEN a message is sent successfully, THE Chat_Screen SHALL clear the text input field and scroll to the newly added message.
3. IF the text input field is empty or contains only whitespace, THEN THE Chat_Screen SHALL disable the send button and not create a Message.
4. THE Chat_Screen SHALL support sending a message by pressing the Enter/Done key on the software keyboard in addition to tapping the send button.
5. WHEN a message is sent, THE Community_Repository SHALL persist the message to local storage so it survives an app restart.

---

### Requirement 4: Mock User Identity

**User Story:** As a user, I want to set a display name and role before chatting, so that other community members can identify me.

#### Acceptance Criteria

1. WHEN the app is launched for the first time and no Mock_User identity exists, THE Community_Screen SHALL prompt the user to enter a username and select a role (Pilgrim or Local) before entering any chat.
2. THE Mock_User identity setup SHALL accept a username between 3 and 30 characters.
3. IF the entered username is fewer than 3 characters or more than 30 characters, THEN THE Community_Screen SHALL display a validation error and prevent saving.
4. WHEN a valid Mock_User identity is saved, THE Community_Repository SHALL persist the username and role to local storage so it is retained across app restarts.
5. WHERE the Admin role is required, THE Community_Screen SHALL only assign the Admin role via a hardcoded admin username list in the MVP, without an authentication flow.

---

### Requirement 5: Pinned Messages

**User Story:** As an admin, I want to pin an important message so that all visitors to the temple community see it prominently.

#### Acceptance Criteria

1. WHILE the current Mock_User has the Admin role, THE Chat_Screen SHALL display a "Pin" action on each message via a long-press context menu.
2. WHEN an Admin long-presses a message and selects "Pin", THE Chat_Screen SHALL set that message as the Pinned_Message for the temple and display it in the sticky banner.
3. WHEN a new message is pinned, THE Community_Repository SHALL replace any previously pinned message for that temple with the new one.
4. WHILE the current Mock_User has the Admin role, THE Chat_Screen SHALL display an "Unpin" action in the sticky banner to remove the Pinned_Message.
5. WHEN the Pinned_Message is removed, THE Chat_Screen SHALL hide the sticky banner.
6. IF the current Mock_User does not have the Admin role, THEN THE Chat_Screen SHALL not display pin or unpin actions.

---

### Requirement 6: Admin Message Deletion

**User Story:** As an admin, I want to delete inappropriate messages, so that the community remains respectful and relevant.

#### Acceptance Criteria

1. WHILE the current Mock_User has the Admin role, THE Chat_Screen SHALL display a "Delete" action on each message via a long-press context menu.
2. WHEN an Admin selects "Delete" on a message, THE Chat_Screen SHALL show a confirmation dialog before removing the message.
3. WHEN deletion is confirmed, THE Community_Repository SHALL remove the message from local storage and THE Chat_Screen SHALL remove it from the visible list.
4. IF the deleted message was the Pinned_Message, THEN THE Chat_Screen SHALL also clear the sticky banner.
5. IF the current Mock_User does not have the Admin role, THEN THE Chat_Screen SHALL not display the delete action.

---

### Requirement 7: Unread Message Tracking

**User Story:** As a pilgrim, I want to see how many new messages I have missed in each temple channel, so that I can prioritize which community to check first.

#### Acceptance Criteria

1. THE Community_Repository SHALL track the timestamp of the last message read by the Mock_User per temple channel.
2. WHEN the Community_Screen is displayed, THE Community_Screen SHALL compute the unread count for each temple as the number of messages with a timestamp after the last-read timestamp.
3. WHEN the user opens a Chat_Screen, THE Community_Repository SHALL update the last-read timestamp for that temple to the timestamp of the most recent message.
4. WHEN the Chat_Screen is closed and the user returns to the Community_Screen, THE Community_Screen SHALL reflect the updated (zero) unread count for the visited temple.
5. THE Notification_Badge SHALL display a maximum visible count of "99+" when the unread count exceeds 99.

---

### Requirement 8: Temple-Specific In-App Notifications

**User Story:** As a pilgrim, I want to receive an in-app notification when a new message arrives in a temple channel I have visited, so that I stay informed without keeping the chat open.

#### Acceptance Criteria

1. WHEN a new message is added to a temple channel that the Mock_User has previously opened, THE Community_Repository SHALL increment the unread count for that channel.
2. WHEN the Community_Screen is visible and a new message arrives in any channel, THE Community_Screen SHALL update the Notification_Badge for that channel without requiring a full screen reload.
3. WHILE the Chat_Screen is open for a specific temple, THE Community_Repository SHALL not increment the unread count for that temple, as the user is actively reading.
4. THE Community_Screen SHALL display a visual indicator (e.g. bold channel name) for channels with unread messages, in addition to the Notification_Badge.

---

### Requirement 9: Media Placeholders (MVP Scope)

**User Story:** As a pilgrim, I want to see that image sharing will be supported in the future, so that I understand the feature roadmap.

#### Acceptance Criteria

1. THE Chat_Screen SHALL display a camera/attachment icon in the input bar as a non-functional placeholder.
2. WHEN the user taps the media attachment icon, THE Chat_Screen SHALL display a bottom sheet or snackbar stating "Media sharing coming soon".
3. THE Message model SHALL include an optional `mediaUrl` field typed as `String?` to support future backend media integration without a breaking model change.

---

### Requirement 10: Local Persistence and Backend Extensibility

**User Story:** As a developer, I want the community data layer to be abstracted behind a repository interface, so that local mock storage can be swapped for a real-time backend without rewriting the UI.

#### Acceptance Criteria

1. THE Community_Repository SHALL be defined as an abstract interface (abstract class or interface) with concrete methods for: loading messages, saving a message, deleting a message, pinning a message, loading/saving Mock_User identity, and loading/saving last-read timestamps.
2. THE Community_Repository SHALL have a concrete `LocalCommunityRepository` implementation backed by SharedPreferences or in-memory storage for Phase 1.
3. WHEN the app initialises the community feature, THE Community_Repository SHALL be provided via Riverpod so that the implementation can be swapped by overriding the provider in tests or future backend integration.
4. THE Message model SHALL be serialisable to and from JSON so that it can be transmitted to a future backend without a breaking change.
5. FOR ALL valid Message objects, serialising to JSON and then deserialising SHALL produce an equivalent Message object (round-trip property).
6. THE Community_Repository interface SHALL NOT expose any SharedPreferences or Flutter-specific storage types in its method signatures, keeping the contract storage-agnostic.

---

## MVP Scope vs Future Scope

### MVP (Phase 1 — this spec)
- Temple channel list with unread badges
- Per-temple chat with text messages, timestamps, role badges
- Mock user identity (username + Pilgrim/Local role, persisted locally)
- Admin role via hardcoded username list
- Pinned messages (admin only)
- Admin message deletion
- Unread message tracking per channel
- In-app notification badge updates
- Media attachment placeholder UI
- Local persistence via SharedPreferences or in-memory
- Repository abstraction layer (Riverpod-provided)
- Message JSON round-trip serialisation

### Future Scope (Phase 2+)
- Real-time backend (Firebase Firestore / WebSocket / Supabase)
- Proper authentication (Firebase Auth / OAuth)
- Push notifications (FCM)
- Image and video media sharing
- Message reactions / emoji
- Reply threading
- Moderation tools (ban, mute)
- Search within a channel
- Deep links to specific messages
- Read receipts
- Online presence indicators
