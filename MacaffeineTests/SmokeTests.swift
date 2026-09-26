import Testing
@testable import Macaffeine

struct SmokeTests {
    @Test func appModuleLoads() {
        #expect(Bool(true))
    }
}
