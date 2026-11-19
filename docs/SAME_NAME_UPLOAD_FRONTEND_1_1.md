# Same-name upload — frontend handoff

Use this when wiring file attach. Two HTTP calls:

| Step | Method and path | Who sets the flag |
| --- | --- | --- |
| 1. Ask for an upload URL | `POST /chat/messages/presignedurls` | Client sends `forceUpload`. Server answers with `duplicate`. |
| 2. Create the chat message | `POST /chat/message` | Client sends `forceUpload` only when the user chose a new copy. `duplicate` is not a field on this API. |

Auth headers on both calls: `licenseKey`, `appSecret`, `userToken`.

This choice exists only while storage quota is enabled for the project. While quota is off, presign always returns `duplicate: false` and a PUT URL. Do not show the same-name banner. Send the message the way you do today, and do not send `forceUpload`.

---

## 1. The two flags

### `forceUpload` — client decides

Boolean on each attachment. Send it on presign, and send it again on the message only for a new copy.

| Value | Meaning |
| --- | --- |
| omitted or `false` | If this user already has that exact file name, reuse the older file. Do not upload. |
| `true` | Upload a new copy even though the name already exists. The new bytes count against quota. |

The value must be a JSON boolean. The string `"true"` is rejected.

### `duplicate` — server decides

Boolean on each object inside `presignedUrls`. Read it. Never send it back on `POST /chat/message`.

| Value | Meaning | What to do |
| --- | --- | --- |
| `false` | This name is new, or the client set `forceUpload: true`. | PUT the bytes, then send the message with the new URLs. |
| `true` | This user already has that exact name. | Do not PUT. There is no presigned URL in this object. Show the warning and let the user pick. |

`duplicate: true` warning text, always this string:

```text
A file with the same name is already in your storage.
```

Show that text and two actions:

1. **Reshare older file** — keep `forceUpload` off, send the older URLs, and set the message `mediaId` to `existingMediaId`.
2. **Upload a copy** — call presign again with `forceUpload: true`, PUT the new URLs, then send the message with `forceUpload: true`.

---

## 2. Client algorithm

Do this for every file the user picks. Match each presign result to the file you sent by `mediaId` (the id you generated for this request).

```text
build attachment:
  mediaId = new id
  mediaType = 0 image | 1 video | 2 audio | 3 file
  nameWithExtension = the file name, including extension
  forceUpload is omitted

POST /chat/messages/presignedurls

if response is 403 and errorCode is 6:
  stop. User is at the quota and this file needs a new upload.
  A reshare-only request does not return this error.

for each item in presignedUrls, matched by mediaId:

  if item.duplicate is false:
    PUT the file bytes to item.mediaPresignedUrl
    PUT the thumbnail bytes to item.thumbnailPresignedUrl
    remember item.mediaUrl and item.thumbnailUrl
    on POST /chat/message, omit forceUpload

  if item.duplicate is true:
    do not PUT
    show warning
    if user taps "Reshare older file":
      do not call presign again
      on POST /chat/message use item.mediaUrl and item.thumbnailUrl
      mediaId must be item.existingMediaId
      name must equal the nameWithExtension you sent
      omit forceUpload
    if user taps "Upload a copy":
      POST /chat/messages/presignedurls again for this file with forceUpload: true
      that response has duplicate: false and new PUT urls
      PUT those urls
      on POST /chat/message set forceUpload: true
      use the new mediaUrl and thumbnailUrl from the second presign
```

The first presign response with `duplicate: true` cannot be uploaded. It has no `mediaPresignedUrl`. The second presign, with `forceUpload: true`, is what returns the PUT URL.

A batch can mix both. One file can be `duplicate: true` and the next `duplicate: false`. Branch per item.

If any file in the batch needs a new object and the user is already at the quota, the whole presign call returns `403`. You do not get a partial list.

---

## 3. `POST /chat/messages/presignedurls`

### Request

```json
{
  "conversationId": "6017d0da21a38e3440b3cb9c",
  "conversationType": 0,
  "attachments": [
    {
      "mediaId": "5df31dba3a22d30037d62066",
      "mediaType": 3,
      "nameWithExtension": "report.pdf"
    }
  ]
}
```

| Field | Rule |
| --- | --- |
| `conversationId` | 24 hex characters. |
| `conversationType` | `0` conversation, `1` bulk messaging, `2` groupcast. Omit it and the server uses `0`. |
| `attachments` | 1 to 10 items. |
| `mediaId` | Your id for this attach attempt. The response echoes it. |
| `mediaType` | `0` image, `1` video, `2` audio, `3` file. |
| `nameWithExtension` | Exact file name. `Report.pdf` and `report.pdf` are different. |
| `forceUpload` | Omit or `false` on the first call. Send `true` only after the user chooses **Upload a copy**. |

Upload-a-copy request for that same file:

```json
{
  "conversationId": "6017d0da21a38e3440b3cb9c",
  "conversationType": 0,
  "attachments": [
    {
      "mediaId": "5df31dba3a22d30037d62066",
      "mediaType": 3,
      "nameWithExtension": "report.pdf",
      "forceUpload": true
    }
  ]
}
```

The name check is this user, in this project, in any conversation. It is not limited to the conversation in the request.

### Response when `duplicate` is `false`

HTTP 200. Upload, then use `mediaUrl` and `thumbnailUrl` on the message. Those are the CDN urls. Do not put `mediaPresignedUrl` on the message.

```json
{
  "msg": "Presigned urls fetched successfully.",
  "presignedUrls": [
    {
      "mediaId": "5df31dba3a22d30037d62066",
      "duplicate": false,
      "ttl": 600,
      "mediaPresignedUrl": "https://bucket.s3.region.amazonaws.com/...?X-Amz-Signature=...",
      "mediaUrl": "https://chatstorage.isometrik.ai/account/project/Attachments/Files/conversation/user_time_report.pdf",
      "thumbnailPresignedUrl": "https://bucket.s3.region.amazonaws.com/...?X-Amz-Signature=...",
      "thumbnailUrl": "https://chatstorage.isometrik.ai/account/project/Thumbnails/Files/conversation/user_time_report.pdf"
    }
  ]
}
```

PUT the raw file bytes to `mediaPresignedUrl` and the thumbnail bytes to `thumbnailPresignedUrl`. Do not change the query string. `ttl` is seconds until those PUT urls expire.

### Response when `duplicate` is `true`

HTTP 200. Do not upload. Keys `mediaPresignedUrl`, `thumbnailPresignedUrl`, and `ttl` are absent.

```json
{
  "msg": "Presigned urls fetched successfully.",
  "presignedUrls": [
    {
      "mediaId": "5df31dba3a22d30037d62066",
      "duplicate": true,
      "warning": "A file with the same name is already in your storage.",
      "mediaUrl": "https://chatstorage.isometrik.ai/account/project/Attachments/Files/older-conversation/older-report.pdf",
      "thumbnailUrl": "https://chatstorage.isometrik.ai/account/project/Thumbnails/Files/older-conversation/older-report.pdf",
      "existingMediaId": "64b1a0c0e4b0f1a2b3c4d5e6",
      "messageId": "64b1a0c0e4b0f1a2b3c4d5e7",
      "conversationId": "64b1a0c0e4b0f1a2b3c4d5e8"
    }
  ]
}
```

| Field | Use it for |
| --- | --- |
| `mediaId` | The id you just sent. Use this to match the file in a batch. |
| `warning` | Banner copy. |
| `mediaUrl` | URL to put on the message if the user reshares. |
| `thumbnailUrl` | Thumbnail to put on the message if the user reshares. |
| `existingMediaId` | The older attachment. Send this as the message attachment `mediaId` when the user reshares. |
| `messageId` | Older message. Display only. |
| `conversationId` | Conversation that holds the older file. It can differ from the conversation you are posting into. |

### Presign errors

| HTTP | Body | What the user hit |
| --- | --- | --- |
| 403 | `{ "error": "Storage quota exceeded.", "errorCode": 6 }` | At least one attachment needs a new object, and `usedBytes` is already at the quota. A request whose every item is an existing name, with `forceUpload` omitted, does not return this. |
| 403 | `{ "error": "Limit of maximum allowed messages reached.", "errorCode": 0 }` | Message signal limit. Unrelated to storage. |
| 400 | `{ "error": "Either conversation not found or not allowed to fetch presigned urls." }` | Conversation missing, or this user cannot post there. |
| 422 | `{ "errors": { ... } }` | Body failed validation. |
| 503 | `{ "error": "Fetch presigned urls service is temporarily unavailable." }` | Retry later. |

---

## 4. `POST /chat/message`

Send the normal message body. The attachment fields that matter for this feature:

| Field | Rule |
| --- | --- |
| `attachmentType` | `0` image, `1` video, `2` audio, `3` document, `8` custom. These are the types quota can count. |
| `mediaId` | New id for a first upload or an upload-a-copy. On a reshare, this must be `existingMediaId` from the `duplicate: true` response. |
| `mediaUrl` | From presign. On a reshare, the older `mediaUrl`. On an upload, the new `mediaUrl`. Never the presigned PUT url. |
| `thumbnailUrl` | Same rule. Required, non-empty string. |
| `name` | Must be the same string as `nameWithExtension` from presign. This is the string the server compares. |
| `mimeType` | Required non-empty string. |
| `extension` | Required non-empty string. |
| `size` | Required integer, at least `1`. Always send the file size in bytes. |
| `forceUpload` | Omit it to reshare or to send a first-time upload. Set `true` only when this message is the new copy you just PUT. |

`size` is always required. It is added to the user's quota only when this name is new, or when `forceUpload` is `true`. A reshare still sends `size`, and the server adds `0` bytes.

### First upload, or any `duplicate: false` result

You already PUT the new object. Omit `forceUpload`.

```json
{
  "messageType": 0,
  "body": "report",
  "showInConversation": true,
  "encrypted": false,
  "conversationId": "6017d0da21a38e3440b3cb9c",
  "deviceId": "device-1",
  "attachments": [
    {
      "attachmentType": 3,
      "mediaId": "new-media-id",
      "mediaUrl": "https://chatstorage.isometrik.ai/account/project/Attachments/Files/conversation/user_time_report.pdf",
      "thumbnailUrl": "https://chatstorage.isometrik.ai/account/project/Thumbnails/Files/conversation/user_time_report.pdf",
      "name": "report.pdf",
      "mimeType": "application/pdf",
      "extension": "pdf",
      "size": 204800
    }
  ]
}
```

The server stores a charge and adds `size` to `usedBytes`.

### Reshare older file

User chose the existing file after `duplicate: true`. Do not PUT. Omit `forceUpload`. `mediaId` is `existingMediaId`. `name` equals `nameWithExtension`. URLs are the ones from the `duplicate: true` object.

```json
{
  "messageType": 0,
  "body": "report",
  "showInConversation": true,
  "encrypted": false,
  "conversationId": "6017d0da21a38e3440b3cb9c",
  "deviceId": "device-1",
  "attachments": [
    {
      "attachmentType": 3,
      "mediaId": "64b1a0c0e4b0f1a2b3c4d5e6",
      "mediaUrl": "https://chatstorage.isometrik.ai/account/project/Attachments/Files/older-conversation/older-report.pdf",
      "thumbnailUrl": "https://chatstorage.isometrik.ai/account/project/Thumbnails/Files/older-conversation/older-report.pdf",
      "name": "report.pdf",
      "mimeType": "application/pdf",
      "extension": "pdf",
      "size": 204800
    }
  ]
}
```

The new message points at the same S3 object. Bytes added are `0`. No second media-list row is stored, so `GET /chat/quota/storage/media` still shows the original file once. This still succeeds when the user is already at the quota.

### Upload a copy

User chose a new copy. You called presign with `forceUpload: true`, then PUT the new URLs. Send `forceUpload: true` and the new CDN urls.

```json
{
  "messageType": 0,
  "body": "report",
  "showInConversation": true,
  "encrypted": false,
  "conversationId": "6017d0da21a38e3440b3cb9c",
  "deviceId": "device-1",
  "attachments": [
    {
      "attachmentType": 3,
      "mediaId": "new-media-id",
      "mediaUrl": "https://chatstorage.isometrik.ai/account/project/Attachments/Files/conversation/user_time_report.pdf",
      "thumbnailUrl": "https://chatstorage.isometrik.ai/account/project/Thumbnails/Files/conversation/user_time_report.pdf",
      "name": "report.pdf",
      "mimeType": "application/pdf",
      "extension": "pdf",
      "size": 204800,
      "forceUpload": true
    }
  ]
}
```

The server stores a second charge for that same name and adds `size`. If `usedBytes + size` does not fit, the message is not created.

### Send success

HTTP 200.

```json
{
  "msg": "Message sent successfully.",
  "messageId": "5ffd543621a38e11ed4e32e4"
}
```

### Send error for quota

HTTP 403. The message was not stored.

```json
{
  "error": "Storage quota exceeded.",
  "errorCode": 6
}
```

You get this when the bytes being added do not fit. A reshare adds `0`, so it does not hit this error because of the file size. A first upload and an upload-a-copy both can.

---

## 5. Which combination to send

| User action | Presign `forceUpload` | Presign `duplicate` | Then |
| --- | --- | --- | --- |
| Attach a name this user does not have | omit | `false` | PUT, then send the message. Omit `forceUpload`. |
| Attach a name this user has, user wants the older file | omit | `true` | Do not PUT. Send the older `mediaUrl` and `thumbnailUrl`. Set `mediaId` to `existingMediaId`. Omit `forceUpload`. |
| Attach a name this user has, user wants a new copy | second call with `true` | `false` | PUT the new urls. Send the new urls with `forceUpload: true`. |
| Quota off | omit | `false` | PUT and send as today. Do not send `forceUpload`. |

Set `forceUpload: true` only after a real PUT of the new presigned URL, and use the new `mediaId` from that second presign. A message whose `mediaId` is already in this user's media list does not add bytes and does not add another list row.

If you omit `forceUpload` but send a new URL for a name that already exists, the server does not add bytes. The message still points at the URL you sent. Only the flag controls charging. Keep the flag and the URL on the same path: older URL with the flag omitted, new URL with the flag `true`.

---

## 6. Implementation checklist

- Generate `mediaId` before presign and match the response item with that id.
- First presign omits `forceUpload`.
- Branch on `duplicate`, per attachment.
- On `duplicate: true`, render `warning` and do not look for a PUT url.
- **Reshare older file** uses `mediaUrl` and `thumbnailUrl` from that item. `name` is the same string as `nameWithExtension`. `mediaId` is `existingMediaId`. No `forceUpload`. The media list stays one row.
- **Upload a copy** calls presign again with `forceUpload: true`, PUTs, then sends `forceUpload: true` with the new `mediaUrl` and `thumbnailUrl`.
- PUT targets are `mediaPresignedUrl` and `thumbnailPresignedUrl`. Message fields are `mediaUrl` and `thumbnailUrl`.
- Treat HTTP 403 `errorCode` 6 on either call as "storage quota exceeded" and leave the draft in place.
- Do not show this banner when quota is off. `GET /chat/quota/storage/usage` returns `quotaEnabled`.
