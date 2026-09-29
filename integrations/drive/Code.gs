/** Private, read-only image bridge. Draft: requires deployment and integration tests.
 * Script Properties: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, MEMES_FOLDER_ID.
 * Runs as owner. Never publish Drive files or embed the owner's OAuth token.
 * Request: POST JSON {accessToken: Supabase user JWT, cardId: UUID}.
 * Uses the caller's JWT and RLS to authorize a catalog entry before reading Drive.
 * Mobile-only initial transport: JSON base64, max 1 MiB source image.
 */
function doPost(e) {
  try {
    if (!e || !e.postData || e.postData.contents.length > 16384) return json_({error:'invalid_request'});
    const input = JSON.parse(e.postData.contents);
    if (typeof input.accessToken !== 'string' || input.accessToken.length > 8192 ||
        typeof input.cardId !== 'string' || !/^[0-9a-f-]{36}$/i.test(input.cardId)) return json_({error:'invalid_request'});
    const props = PropertiesService.getScriptProperties();
    const base = props.getProperty('SUPABASE_URL');
    const key = props.getProperty('SUPABASE_PUBLISHABLE_KEY');
    const folderId = props.getProperty('MEMES_FOLDER_ID');
    if (!base || !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(base) || !key || !folderId) return json_({error:'not_configured'});
    const response = UrlFetchApp.fetch(base + '/rest/v1/cards?id=eq.' + encodeURIComponent(input.cardId) + '&select=drive_file_id,mime_type,version', {
      headers:{apikey:key, Authorization:'Bearer ' + input.accessToken}, muteHttpExceptions:true
    });
    if (response.getResponseCode() !== 200) return json_({error:'unauthorized'});
    const rows = JSON.parse(response.getContentText());
    if (rows.length !== 1) return json_({error:'not_found'});
    const file = DriveApp.getFileById(rows[0].drive_file_id);
    const parents = file.getParents();
    let allowed = false;
    while (parents.hasNext()) if (parents.next().getId() === folderId) allowed = true;
    if (!allowed || file.isTrashed()) return json_({error:'not_found'});
    const mime = file.getMimeType();
    if (!['image/webp','image/jpeg','image/png'].includes(mime) || file.getSize() > 1048576) return json_({error:'unsupported_image'});
    return json_({cardId:input.cardId, version:rows[0].version, mimeType:mime, base64:Utilities.base64Encode(file.getBlob().getBytes())});
  } catch (_) {
    // No token, file ID or internal exception text in public responses or logs.
    return json_({error:'unavailable'});
  }
}
function doGet() { return json_({service:'Nuestro rincón',status:'POST required'}); }
function json_(data) { return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON); }
