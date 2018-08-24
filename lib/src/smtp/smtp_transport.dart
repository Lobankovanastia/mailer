part of mailer;

class SmtpTransport extends Transport {
  SmtpOptions options;

  SmtpTransport(this.options);

  Future send(Envelope envelope) => new SmtpClient(options).send(envelope);

  Future sendAll(List<Envelope> envelopes) => Future.wait(envelopes.map(send));
}
