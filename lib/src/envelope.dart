part of mailer;

/**
 * This class represents an envelope that can be sent to someone/some people.
 *
 * Use [text] to specify plaintext body or [html] to specify HTML body. Use both to provide a fallback for old email clients.
 *
 * Recipients are defined as a [List] of [String]s.
 */
class Envelope {
  List<String> recipients = [];
  List<String> ccRecipients = [];
  List<String> bccRecipients = [];
  List<Attachment> attachments = [];
  String from = 'anonymous@${Platform.localHostname}';
  String fromName;
  List<String> replyTos;
  String sender;
  String senderName;
  String subject;
  String text;
  String html;
  String listUnsubscribe;
  String identityString = 'mailer';
  Encoding encoding = utf8;

  bool _isDelivered = false;
  int _counter = 0;

  /**
   * Returns the envelope as a String that is suitable for use in SMTP DATA section.
   *
   * This method automatically sanitizes all fields.
   */
  Future<String> getContents() {
    return new Future(() {
      var buffer = new StringBuffer();

      if (subject != null)
        buffer.write('Subject: ${sanitizeField(subject)}\r\n');

      if (from != null) {
        var fromData = Address.sanitize(from);

        final name = sanitizeName(fromName);
        if (name != null) {
          fromData = '$name <$fromData>';
        }

        buffer.write('From: $fromData\r\n');
      }

      if (sender != null) {
        var senderData = Address.sanitize(sender);

        final name = sanitizeName(senderName);
        if (name != null) {
          senderData = '$name <$senderData>';
        }

        buffer.write('Sender: $senderData\r\n');
      }

      if (recipients != null && recipients.isNotEmpty) {
        var to = recipients.map(Address.sanitize).join(',');
        buffer.write('To: $to\r\n');
      }

      if (ccRecipients != null && ccRecipients.isNotEmpty) {
        var cc = ccRecipients.map(Address.sanitize).join(',');
        buffer.write('Cc: $cc\r\n');
      }

      if (bccRecipients != null && bccRecipients.isNotEmpty) {
        var bcc = bccRecipients.map(Address.sanitize).join(',');
        buffer.write('Bcc: $bcc\r\n');
      }

      if (replyTos != null && replyTos.isNotEmpty) {
        var replyToData = replyTos.map(Address.sanitize).join(',');
        buffer.write('Reply-To: $replyToData\r\n');
      }

      if (listUnsubscribe != null && listUnsubscribe.isNotEmpty)
        buffer.write('List-Unsubscribe: $listUnsubscribe\r\n');

      // Since TimeZone is not implemented in DateFormat we need to use UTC for proper Date header generation time
      buffer.write('Date: ' +
          new DateFormat('EEE, dd MMM yyyy HH:mm:ss +0000')
              .format(new DateTime.now().toUtc()) +
          '\r\n');
      buffer.write('X-Mailer: Dart Mailer library\r\n');
      buffer.write('Mime-Version: 1.0\r\n');

      // Create boundary string.
      var boundary =
          '$identityString-?=_${++_counter}-${new DateTime.now().millisecondsSinceEpoch}';

      // Alternative or mixed?
      var multipartType =
          html != null && text != null ? 'alternative' : 'mixed';

      buffer.write('Content-Type: multipart/$multipartType; ' +
          'boundary="$boundary"\r\n\r\n');

//parts in a multipart MIME message should be in order of increasing preference
//refer: https://stackoverflow.com/questions/5188605/gmail-displays-plain-text-email-instead-html

      // Insert text message.
      if (text != null) {
        buffer.write('--$boundary\r\n');
        buffer.write('Content-Type: text/plain; charset="${encoding.name}"\r\n');
        buffer.write('Content-Transfer-Encoding: 7bit\r\n\r\n');
        buffer.write('$text\r\n\r\n'); // TODO: ensure wrapped to at least 1000
      }

      // Insert HTML message.
      if (html != null) {
        buffer.write('--$boundary\r\n');
        buffer.write('Content-Type: text/html; charset="${encoding.name}"\r\n');
        buffer.write('Content-Transfer-Encoding: 7bit\r\n\r\n');
        buffer.write('$html\r\n\r\n'); // TODO: ensure wrapped to at least 1000
      }

      // Add all attachments.
      return Future.forEach(attachments, (attachment) {
        var filename = basename(attachment.file.path);

        return attachment.file.readAsBytes().then((bytes) {
          // Chunk'd (76 chars per line) base64 string, separated by "\r\n".
          var contents = chunkEncodedBytes(base64.encode(bytes));

          buffer.write('--$boundary\r\n');
          buffer.write(
              'Content-Type: ${_getMimeType(attachment.file.path)}; name="$filename"\r\n');
          buffer.write('Content-Transfer-Encoding: base64\r\n');
          buffer.write(
              'Content-Disposition: attachment; filename="$filename"\r\n\r\n');
          buffer.write('$contents\r\n\r\n');
        });
      }).then((_) {
        buffer.write(
            '--$boundary--\r\n\r\n.');

        return buffer.toString();
      });
    });
  }
}

String _getMimeType(String path) {
  final mtype = lookupMimeType(path);
  return mtype != null ? mtype : 'application/octet-stream';
}
