final class ActionRequestHandler: CopyActionHandler, @unchecked Sendable {
    override var kind: QuickActionKind { .options }
}
