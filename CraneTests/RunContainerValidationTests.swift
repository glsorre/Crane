@testable import Crane
import ContainerResource
import ContainerizationOCI
import XCTest

@MainActor
final class RunContainerValidationTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        ContainersStore.shared.stop()
        ContainersStore.shared.containers = []
        ImagesStore.shared.stop()
        VolumesStore.shared.stop()
        NetworksStore.shared.stop()
    }

    // MARK: - imageValidationMessage

    func testImageValidation() {
        let vm = RunContainerViewModel()
        XCTAssertNotNil(vm.imageValidationMessage)

        vm.selectedImageID = "docker.io/library/alpine:latest"
        XCTAssertNil(vm.imageValidationMessage)
    }

    // MARK: - nameValidationMessage

    func testNameValidationEmpty() {
        let vm = RunContainerViewModel()
        XCTAssertNotNil(vm.nameValidationMessage)

        vm.name = "   "
        XCTAssertNotNil(vm.nameValidationMessage)
    }

    func testNameValidationValid() {
        let vm = RunContainerViewModel()
        vm.name = "my-container"
        XCTAssertNil(vm.nameValidationMessage)
    }

    // MARK: - commandValidationMessage

    func testCommandValidationNoImageReturnsNil() {
        let vm = RunContainerViewModel()
        XCTAssertNil(vm.commandValidationMessage)
    }

    func testCommandValidationNoDefaultRequiresExecutable() {
        let vm = RunContainerViewModel()
        vm.selectedImageID = "alpine"
        vm.useImageDefaultCommand = true
        XCTAssertNotNil(vm.commandValidationMessage)
    }

    func testCommandValidationCustomExecutable() {
        let vm = RunContainerViewModel()
        vm.selectedImageID = "alpine"
        vm.useImageDefaultCommand = false
        vm.executable = ""
        XCTAssertNotNil(vm.commandValidationMessage)

        vm.executable = "/bin/sh"
        XCTAssertNil(vm.commandValidationMessage)
    }

    // MARK: - environmentValidationMessage

    func testEnvironmentValidation() {
        let vm = RunContainerViewModel()
        vm.environment = ""
        XCTAssertNil(vm.environmentValidationMessage)

        vm.environment = "FOO=bar"
        XCTAssertNil(vm.environmentValidationMessage)

        vm.environment = "FOO=bar\nBAR=baz"
        XCTAssertNil(vm.environmentValidationMessage)

        vm.environment = "FOO=bar\nBROKEN"
        XCTAssertNotNil(vm.environmentValidationMessage)
    }

    // MARK: - portValidationMessage

    func testPortValidationBlankAllowed() {
        let vm = RunContainerViewModel()
        vm.addPort()
        XCTAssertNil(vm.portValidationMessage)
    }

    func testPortValidationMissingFields() {
        let vm = RunContainerViewModel()
        vm.ports = [PortEntry(hostPort: "8080", containerPort: "", proto: .tcp)]
        XCTAssertNotNil(vm.portValidationMessage)
    }

    func testPortValidationOutOfRange() {
        let vm = RunContainerViewModel()
        vm.ports = [PortEntry(hostPort: "0", containerPort: "80", proto: .tcp)]
        XCTAssertNotNil(vm.portValidationMessage)

        vm.ports = [PortEntry(hostPort: "70000", containerPort: "80", proto: .tcp)]
        XCTAssertNotNil(vm.portValidationMessage)
    }

    func testPortValidationDuplicate() {
        let vm = RunContainerViewModel()
        vm.ports = [
            PortEntry(hostPort: "8080", containerPort: "80", proto: .tcp),
            PortEntry(hostPort: "8080", containerPort: "81", proto: .tcp),
        ]
        XCTAssertNotNil(vm.portValidationMessage)
    }

    func testPortValidationDifferentProtosOK() {
        let vm = RunContainerViewModel()
        vm.ports = [
            PortEntry(hostPort: "8080", containerPort: "80", proto: .tcp),
            PortEntry(hostPort: "8080", containerPort: "80", proto: .udp),
        ]
        XCTAssertNil(vm.portValidationMessage)
    }

    func testPortValidationValid() {
        let vm = RunContainerViewModel()
        vm.ports = [PortEntry(hostPort: "8080", containerPort: "80", proto: .tcp)]
        XCTAssertNil(vm.portValidationMessage)
    }

    // MARK: - mountValidationMessage

    func testMountValidationBindNeedsSource() {
        let vm = RunContainerViewModel()
        vm.mounts = [MountEntry(type: .bind, source: "", destination: "/data")]
        XCTAssertNotNil(vm.mountValidationMessage)
    }

    func testMountValidationNeedsDestination() {
        let vm = RunContainerViewModel()
        vm.mounts = [MountEntry(type: .bind, source: "/tmp", destination: "")]
        XCTAssertNotNil(vm.mountValidationMessage)
    }

    func testMountValidationTmpfsSourceOptional() {
        let vm = RunContainerViewModel()
        vm.mounts = [MountEntry(type: .tmpfs, source: "", destination: "/tmp")]
        XCTAssertNil(vm.mountValidationMessage)
    }

    // MARK: - socketValidationMessage

    func testSocketValidation() {
        let vm = RunContainerViewModel()
        vm.sockets = [SocketEntry(hostPath: "/var/sock", containerPath: "")]
        XCTAssertNotNil(vm.socketValidationMessage)

        vm.sockets = [SocketEntry(hostPath: "/var/sock", containerPath: "/srv/sock")]
        XCTAssertNil(vm.socketValidationMessage)
    }

    // MARK: - shellSplit

    func testShellSplitSimple() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellSplit("a b c"), ["a", "b", "c"])
    }

    func testShellSplitDoubleQuotes() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellSplit("\"hello world\" foo"), ["hello world", "foo"])
    }

    func testShellSplitSingleQuotesPreserveBackslash() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellSplit("'a\\b' c"), ["a\\b", "c"])
    }

    func testShellSplitEscape() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellSplit("a\\ b c"), ["a b", "c"])
    }

    func testShellSplitEmpty() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellSplit(""), [])
        XCTAssertEqual(vm.shellSplit("   "), [])
    }

    // MARK: - shellJoin

    func testShellJoinNoSpaces() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellJoin(["a", "b", "c"]), "a b c")
    }

    func testShellJoinQuotesSpaces() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellJoin(["hello world", "x"]), "\"hello world\" x")
    }

    func testShellJoinEscapesDoubleQuotes() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.shellJoin(["a\"b"]), "\"a\\\"b\"")
    }

    // MARK: - suggestedName

    func testSuggestedNameStripsRegistryAndTag() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.suggestedName(for: "docker.io/library/alpine:latest"), "alpine-latest")
    }

    func testSuggestedNameStripsDigest() {
        let vm = RunContainerViewModel()
        let name = vm.suggestedName(for: "alpine@sha256:abcdef")
        XCTAssertEqual(name, "alpine")
    }

    func testSuggestedNameSanitizesInvalidChars() {
        let vm = RunContainerViewModel()
        let name = vm.suggestedName(for: "weird/Image+Name!")
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.contains("+"))
        XCTAssertFalse(name.contains("!"))
        XCTAssertFalse(name.contains("/"))
    }

    func testSuggestedNameFallbackWhenEmpty() {
        let vm = RunContainerViewModel()
        XCTAssertEqual(vm.suggestedName(for: "---"), "container")
    }
}
