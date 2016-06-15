component extends='testbox.system.BaseSpec' {
    
    function beforeAll() {
        this.CUT = new BaseSpecs.ColdBoxBaseSpec();
        getMockBox().prepareMock(this.CUT);

        // Set the appMapping for testing
        variables.mockBaseTestCase = getMockBox().createMock('coldbox.system.testing.BaseTestCase');
        this.CUT.$property(propertyName = 'baseTestCase', mock = mockBaseTestCase);
        variables.mockBaseTestCase.$property(propertyName = 'appMapping', mock = '/SampleApp');
        variables.mockBaseTestCase.beforeAll();

        // Set up the parent ColdBox BaseTestCase
        this.CUT.beforeAll();
    }

    function run() {
        describe('BaseSpec — Debugging', function() {

            beforeEach(function() {
                // Read in a sample html page
                variables.html = fileRead(expandPath('/tests/resources/login-page.html'));

                // Parse the html page in
                makePublic(this.CUT, 'parse', 'parsePublic');
                this.CUT.parsePublic(variables.html);

                // Add a mock ColdBox request context
                mockEvent = getMockBox().createMock('coldbox.system.web.context.RequestContext');
                variables.rc = { private = false };
                variables.prc = { private = true };
                mockEvent.$('getCollection', rc);
                mockEvent.$('getPrivateCollection', prc);
                this.CUT.$property(propertyName = 'event', mock = mockEvent);

                // Set the default request method to 'visit'
                this.CUT.$property(propertyName = 'requestMethod', mock = 'visit');
            });

            feature('debugCollection', function() {
                it("should call TestBox's debug method with the current request collection object", function() {
                    this.CUT.$('debug').$args(variables.rc);

                    this.CUT.debugCollection();

                    var callLog = this.CUT.$callLog().debug;

                    expect(ArrayLen(callLog)).toBe(1);
                    expect(callLog[1][1]).toBe(variables.rc);
                });
            });

            feature('debugPrivateCollection', function() {
                it("should call TestBox's debug method with the current private request collection object", function() {
                    this.CUT.$('debug').$args(variables.prc);

                    this.CUT.debugPrivateCollection();

                    var callLog = this.CUT.$callLog().debug;

                    expect(ArrayLen(callLog)).toBe(1);
                    expect(callLog[1][1]).toBe(variables.prc);
                });
            });            

        });
    }
}
