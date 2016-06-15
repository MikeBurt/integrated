/**
* Abstract component for fluent integration tests.
* Needs to be implemented for each framework it targets.
*
* @doc_abstract true
*/
component extends="testbox.system.compat.framework.TestCase" {

    // The jsoup parser object
    property name='parser' type='org.jsoup.parser.Parser';
    // The DOM-specific assertion engine
    property name='DOMAssertionEngine' type='Integrated.Engines.Assertion.Contracts.DOMAssertionEngine';
    // The Framework-specific assertion engine
    property name='frameworkAssertionEngine' type='Integrated.Engines.Assertion.Contracts.FrameworkAssertionEngine';
    // The interaction engine
    property name='interactionEngine' type='Integrated.Engines.Interaction.Contracts.FrameworkAssertionEngine';
    // A database testing helper library
    property name='dbUtils' type='Integrated.BaseSpecs.DBUtils';
    // The parsed jsoup document object
    property name='page' type='org.jsoup.nodes.Document';
    // The ColdBox event object
    property name='event' type='coldbox.system.web.context.RequestContext';
    // The way we last made a request
    property name='requestMethod' type='string';

    // Boolean flag to turn on automatic database transactions
    property name='useDatabaseTransactions' type='boolean' default=false;
    // Boolean flag to turn on persisting of the session scope between specs
    property name='persistSessionScope' type='boolean' default=false;


    /***************************** Set Up *******************************/

    /**
    * Sets up the needed dependancies for Integrated.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    *
    * @beforeAll
    */
    public AbstractBaseSpec function beforeAll(
        parser = createObject('java', 'org.jsoup.Jsoup'),
        DOMAssertionEngine DOMAssertionEngine = new Integrated.Engines.Assertion.JSoupAssertionEngine(),
        required FrameworkAssertionEngine frameworkAssertionEngine,
        InteractionEngine interactionEngine = new Integrated.Engines.Interaction.JSoupInteractionEngine(),
        additionalMatchers = 'Integrated.BaseSpecs.DBMatchers'
    ) {
        addMatchers(arguments.additionalMatchers);

        // Initialize all component variables
        variables.DOMAssertionEngine = arguments.DOMAssertionEngine;
        variables.frameworkAssertionEngine = arguments.frameworkAssertionEngine;
        variables.interactionEngine = arguments.interactionEngine;
        variables.interactionEngine.setDOMAssertionEngine(variables.DOMAssertionEngine);
        variables.parser = arguments.parser;
        variables.page = '';
        setEvent( '' );
        setRequestMethod( '' );
        this.useDatabaseTransactions = false;
        this.persistSessionScope = false;

        return this;
    }

    public void function afterAll() {}


    /***************************** Abstract Methods *******************************/

    /**
    * @doc_abstract true
    *
    * Make a request specific to the framework extending the BaseSpec
    *
    * @method The HTTP method to use for the request.
    * @route Optional. The route to execute. Default: ''.
    * @event Optional. The event to execute. Default: ''.
    * @parameters Optional. A struct of parameters to attach to the request. Default: {}.
    *
    * @throws TestBox.AssertionFailed
    * @return Framework-specific event
    */
    public function makeFrameworkRequest(required string method, string event, string route, struct parameters = {}) {
        throw('Method is abstract and must be implemented in a concrete component.');
    }

    /**
    * @doc_abstract true
    *
    * Returns the framework route portion of a url.
    *
    * @url A full url
    *
    * @return string
    */
    private string function parseFrameworkRoute(required string url) {
        throw('Method is abstract and must be implemented in a concrete component.');
    }

    /**
    * @doc_abstract true
    *
    * Returns the html string from a Framework-specific event object.
    *
    * @event The Framework-specific event object.
    *
    * @return string
    */
    private string function getHTML(event) {
        throw('Method is abstract and must be implemented in a concrete component.');
    }

    /**
    * @doc_abstract true
    *
    * Returns true if the response is a redirect
    *
    * @event The Framework-specific event object.
    *
    * @return boolean
    */
    private boolean function isRedirect(event) {
        throw('Method is abstract and must be implemented in a concrete component.');   
    }

    /**
    * @doc_abstract true
    *
    * Returns the redirect event name
    *
    * @event The Framework-specific event object.
    *
    * @return string
    */
    private string function getRedirectEvent(event) {
        throw('Method is abstract and must be implemented in a concrete component.');   
    }

    /**
    * @doc_abstract true
    *
    * Returns the inputs for the redirect event, if any.
    *
    * @event The Framework-specific event object.
    *
    * @return struct
    */
    private struct function getRedirectInputs(event) {
        throw('Method is abstract and must be implemented in a concrete component.');   
    }


    /***************************** Lifecycle Methods *******************************/

    /**
    * Wraps each spec in a database transaction, if desired.
    * Automatically runs around each TestBox spec.
    *
    * @spec The TestBox spec to execute.
    *
    * @aroundEach
    */
    public void function shouldUseDatabaseTransactions(spec) {
        if (this.useDatabaseTransactions) {
            wrapInDatabaseTransaction(arguments.spec);
        }
        else {
            arguments.spec.body();
        }
    }

    /**
    * Wraps each spec in a database transaction.
    *
    * @spec The TestBox spec to execute.
    */
    private void function wrapInDatabaseTransaction(spec) {
        transaction action="begin" {
            try {
                arguments.spec.body();
            }
            catch (any e) {
                rethrow;
            }
            finally {
                transaction action="rollback";
            }
        }
    }

    /**
    * Clears the session scope before each spec, if desired.
    * Automatically runs around each TestBox spec.
    *
    * @beforeEach
    */
    public void function shouldPersistSessionScope() {
        if (! this.persistSessionScope) {
            clearSessionScope();
        }
    }

    /**
    * Clears the session scope
    */
    private void function clearSessionScope() {
        structClear(session);
    }


    /***************************** Interactions *******************************/


    /**
    * Makes a request to a ColdBox route.
    *
    * @route The ColdBox route to visit, e.g. `/login` or `/posts/4`. Integrated will build the full url based on ColdBox settings (including `index.cfm`, if needed).
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function visit(required string route) {
        makeRequest(method = 'GET', route = arguments.route);

        return this;
    }

    /**
    * Makes a request to a ColdBox event.
    *
    * @event The ColdBox event to visit, e.g. `Main.index` or `Posts.4`.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function visitEvent(required string event) {
        makeRequest(method = 'GET', event = arguments.event);

        return this;
    }

    /**
    * Clicks on a link in the current page.
    *
    * @link A selector of a link or the text of the link to click.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function click(required string link) {
        var href = variables.DOMAssertionEngine.findLink(argumentCollection = arguments);

        var route = parseFrameworkRoute(href);
        route = isNull(route) ? '' : route;

        this.visit(route);

        return this;
    }

    /**
    * Types a value in to a form field.
    *
    * @text The value to type in the form field.
    * @element The element selector or name to type the value in to.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function type(required string text, required string element) {
        variables.interactionEngine.type(argumentCollection = arguments);

        return this;
    }

    /**
    * Checks a checkbox.
    *
    * @element The selector or name of the checkbox to check.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function check(required string element) {
        variables.interactionEngine.check(argumentCollection = arguments);

        return this;
    }

    /**
    * Unchecks a checkbox.
    *
    * @element The selector or name of the checkbox to uncheck.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function uncheck(required string element) {
        variables.interactionEngine.uncheck(argumentCollection = arguments);

        return this;
    }

    /**
    * Selects a given option in a given select field.
    *
    * @option The value or text to select.
    * @element The selector or name to choose the option in.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function select(required string option, required string element) {
        variables.interactionEngine.select(argumentCollection = arguments);

        return this;
    }

    /**
    * Press a submit button.
    *
    * @button The selector or name of the button to press.
    * @overrideEvent Optional. The event to run instead of the form's default. Default: ''.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function press(required string button, string overrideEvent = '') {
        return this.submitForm(
            button = arguments.button,
            overrideEvent = arguments.overrideEvent
        );
    }

    /**
    * Submits a form
    *
    * @button The selector or name of the button to press.
    * @inputs Optional. The form values to submit.  If not provided, uses the values stored in Integrated combined with any values on the current page. Default: {}.
    * @overrideEvent Optional. The event to run instead of the form's default. Defeault: ''.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function submitForm(
        required string button,
        struct inputs = {},
        string overrideEvent = ''
    ) {
        // Send to the interactionEngine and get back the inputs
        var pageForm = variables.DOMAssertionEngine.findForm(arguments.button);

        if (StructIsEmpty(arguments.inputs)) {
            // Put the form values from the current page in to the variables.input struct
            extractValuesFromForm(pageForm);

            arguments.inputs = variables.interactionEngine.getInputs();
        }

        // Send to the requestEngine and get back the event
        var event = '';
        if (arguments.overrideEvent != '') {
            event = makeRequest(
                method = pageForm.attr('method'),
                event = arguments.overrideEvent,
                parameters = arguments.inputs
            );
        }
        else {
            event = makeRequest(
                method = pageForm.attr('method'),
                route = parseFrameworkRoute(pageForm.attr('action')),
                parameters = arguments.inputs
            );
        }

        // Send the event to the frameworkAssertionEngine
        variables.frameworkAssertionEngine.setEvent(event);
        // Send the html to the DOMAssertionEngine
        variables.DOMAssertionEngine.parse(
            variables.frameworkAssertionEngine.getHTML()
        );

        return this;
    }

    /**
    * Makes a request internally through ColdBox using `execute()`.
    * Either a route or an event must be passed in.
    *
    * @method The HTTP method to use for the request.
    * @route Optional. The ColdBox route to execute. Default: ''.
    * @event Optional. The ColdBox event to execute. Default: ''.
    * @parameters Optional. A struct of parameters to attach to the request.  The parameters are attached to ColdBox's RequestContext collection. Default: {}.
    *
    * @throws TestBox.AssertionFailed
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public function makeRequest(
        required string method,
        string route,
        string event,
        struct parameters = {}
    ) {
        // Make sure the method is always all caps
        arguments.method = UCase(arguments.method);

        // Must pass in a route or an event.
        if (!StructKeyExists(arguments, 'route') && !StructKeyExists(arguments, 'event')) {
            throw(
                type = 'TestBox.AssertionFailed',
                message = 'Must pass either a route or an event to the makeRequest() method.'
            );
        }

        // Clear out the requestMethod in case the call fails
        setRequestMethod('');

        // Make a framework-specific request
        var event = makeFrameworkRequest(argumentCollection = arguments);
        setEvent(event);

        // Clear out the inputs for the next request.
        variables.interactionEngine.reset();

        // Set the requestMethod now that we've finished the request.
        if (StructKeyExists(arguments, 'route')) {
            setRequestMethod( 'visit' );
        }
        else {
            setRequestMethod( 'visitEvent' );
        }

        // Follow any redirects found
        if (isRedirect(variables.event)) {
            if (StructKeyExists(arguments, 'route')) {
                return makeRequest(
                    method = arguments.method,
                    route = getRedirectEvent(variables.event),
                    parameters = getRedirectInputs(variables.event)
                );
            }
            else {
                return makeRequest(
                    method = arguments.method,
                    event = getRedirectEvent(variables.event),
                    parameters = getRedirectInputs(variables.event)
                );
            }
        }

        // Parse the html and set it to the current page
        var html = getHTML(variables.event);
        parse(html);

        return event;
    }


    /***************************** Expectations *******************************/


    /**
    * Verifies the route of the current page.
    * This method cannot be used after visiting a page using an event.
    *
    * @route The expected route.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seePageIs(required string route) {
        variables.frameworkAssertionEngine.seePageIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies the title of the current page.
    *
    * @title The expected title.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeTitleIs(required string title) {
        variables.DOMAssertionEngine.seeTitleIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies the ColdBox view of the current page.
    *
    * @view The expected view.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeViewIs(required string view) {
        variables.frameworkAssertionEngine.seeViewIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies the ColdBox handler of the current page.
    *
    * @handler The expected handler.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeHandlerIs(required string handler) {
        variables.frameworkAssertionEngine.seeHandlerIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies the ColdBox action of the current page.
    *
    * @action The expected action.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeActionIs(required string action) {
        variables.frameworkAssertionEngine.seeActionIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies the ColdBox event of the current page.
    *
    * @event The expected event.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeEventIs(required string event) {
        variables.frameworkAssertionEngine.seeEventIs(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that the given text exists in any element on the current page.
    *
    * @text The expected text.
    * @negate Optional. If true, throw an exception if the text IS found on the current page. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function see(required string text, boolean negate = false) {
        variables.DOMAssertionEngine.see(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that the given text does not exist in any element on the current page.
    *
    * @text The text that should not appear.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSee(required string text) {
        return this.see(text = arguments.text, negate = true);
    }

    /**
    * Verifies that the given element contains the given text on the current page.
    *
    * @element The provided element.
    * @text The expected text.
    * @negate Optional. If true, throw an exception if the element DOES contain the given text on the current page. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeInElement(
        required string element,
        required string text,
        boolean negate = false
    ) {
        variables.DOMAssertionEngine.seeInElement(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that the given element does not contain the given text on the current page.
    *
    * @element The provided element.
    * @text The text that should not be found.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeInElement(
        required string element,
        required string text
    ) {
        return this.seeInElement(
            element = arguments.element,
            text = arguments.text,
            negate = true
        );
    }

    /**
    * Verifies that a link with the given text exists on the current page.
    * Can also take an optional url parameter.  If provided, it verifies the link found has the given url.
    *
    * @text The expected text of the link.
    * @url Optional. The expected url of the link. Default: ''.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeLink(required string text, string url = '') {
        variables.DOMAssertionEngine.seeLink(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that a link with the given text does not exist on the current page.
    * Can also take an optional url parameter.  If provided, it verifies the link found does not have the given url.
    *
    * @text The text of the link that should not be found.
    * @url Optional. The url that should not be found. Default: ''.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeLink(required string text, string url = '') {
        variables.DOMAssertionEngine.dontSeeLink(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that a field with the given value exists on the current page.
    *
    * @element The selector or name of the field.
    * @value The expected value of the field.
    * @negate Optional. If true, throw an exception if the field DOES contain the given text on the current page. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeInField(
        required string element,
        required string value,
        boolean negate = false
    ) {
        variables.DOMAssertionEngine.seeInField(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that a field with the given value exists on the current page.
    *
    * @element The selector or name of the field.
    * @value The value of the field to not find.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeInField(required string element, required string value) {
        return this.seeInField(
            element = arguments.element,
            value = arguments.value,
            negate = true
        );
    }

    /**
    * Verifies that a checkbox is checked on the current page.
    *
    * @element The selector or name of the checkbox.
    * @negate Optional. If true, throw an exception if the checkbox IS checked on the current page. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeIsChecked(
        required string element,
        boolean negate = false
    ) {
        variables.DOMAssertionEngine.seeIsChecked(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that a field with the given value exists on the current page.
    *
    * @element The selector or name of the field.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeIsChecked(required string element) {
        return this.seeIsChecked(
            element = arguments.element,
            negate = true
        );
    }

    /**
    * Verifies that a given selector has a given option selected.
    *
    * @element The selector or name of the select field.
    * @value The value or text of the option that should exist.
    * @negate Optional. If true, throw an exception if the option IS selected in the given select field on the current page. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeIsSelected(
        required string element,
        required string value,
        boolean negate = false
    ) {
        variables.DOMAssertionEngine.seeIsSelected(argumentCollection = arguments);

        return this;
    }

    /**
    * Verifies that a given selector does not have a given option selected.
    *
    * @element The selector or name of the select field.
    * @value The value or text of the option that should exist.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeIsSelected(
        required string element,
        required string value
    ) {
        return this.seeIsSelected(
            element = arguments.element,
            value = arguments.value,
            negate = true
        );
    }

    /**
    * Verifies that a given struct of keys and values exists in a row in a given table.
    *
    * @table The table name to look for the data in.
    * @data A struct of data to verify exists in a row in the given table.
    * @datasource Optional. A datasource to use instead of the default datasource. Default: ''.
    * @query Optional. A query to use for a query of queries.  Mostly useful for testing. Default: ''.
    * @negate Optional. If true, throw an exception if the data DOES exist in the given table. Default: false.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function seeInTable(
        required string table,
        required struct data,
        string datasource = '',
        any query = '',
        boolean negate = false
    ) {
        if (negate) {
            expect(arguments.data).notToBeInTable(
                table = arguments.table,
                datasource = arguments.datasource,
                query = arguments.query
            );
        }
        else {
            expect(arguments.data).toBeInTable(
                table = arguments.table,
                datasource = arguments.datasource,
                query = arguments.query
            );
        }

        return this;
    }

    /**
    * Verifies that a given struct of keys and values does not exist in a row in a given table.
    *
    * @table The table name to look for the data in.
    * @data A struct of data to verify exists in a row in the given table.
    * @datasource Optional. A datasource to use instead of the default datasource. Default: ''.
    * @query Optional. A query to use for a query of queries.  Mostly useful for testing. Default: ''.
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function dontSeeInTable(
        required string table,
        required struct data,
        string datasource = '',
        any query = ''
    ) {
        return this.seeInTable(
            table = arguments.table,
            data = arguments.data,
            datasource = arguments.datasource,
            query = arguments.query,
            negate = true
        );
    }


    /**************************** Helper Methods ******************************/

    /**
    * Sets the framework event
    *
    * @event The framework event
    */
    private void function setEvent( required event ) {
        variables.event = arguments.event;
        variables.frameworkAssertionEngine.setEvent(arguments.event);

        return;
    }

    /**
    * Sets the request method
    *
    * @event The request method
    */
    private void function setRequestMethod( required string requestMethod ) {
        variables.frameworkAssertionEngine.setRequestMethod( arguments.requestMethod );
    }

    /**
    * Gets the request method
    */
    public string function getRequestMethod() {
        return variables.frameworkAssertionEngine.getRequestMethod();
    }



    /**
    * Retrives the last parsed page.
    * Throws an exception if there is no parsed page available.
    *
    * @throws TestBox.AssertionFailed
    * @return org.jsoup.nodes.Document
    */    
    private function getParsedPage() {
        if (IsSimpleValue(variables.page)) {
            throw(
                type = 'TestBox.AssertionFailed',
                message = 'Cannot make assertions until you visit a page.  Make sure to run visit() or visitEvent() first.'
            );
        }

        return variables.page;
    }

    /**
    * Retrives the last ColdBox request context (event) ran.
    * Throws an exception if there is no event available.
    *
    * @throws TestBox.AssertionFailed
    * @return coldbox.system.web.context.RequestContext
    */
    private function getEvent() {
        if (IsSimpleValue(variables.event)) {
            throw(
                type = 'TestBox.AssertionFailed',
                message = 'Cannot make assertions until you visit a page.  Make sure to run visit() or visitEvent() first.'
            );
        }

        return variables.event;
    }

    /**
    * Parses an html string.
    * If an empty string is passed in, the current page is set to an empty string instead of parsing the page.
    *
    * @htmlString The html string to parse.
    */
    private void function parse(required string htmlString) {
        variables.DOMAssertionEngine.parse(argumentCollection = arguments);

        if (arguments.htmlString == '') {
            variables.page = arguments.htmlString;
            return;
        }

        variables.page = variables.parser.parse(htmlString);

        return;
    }

    public struct function getInputs() {
        return variables.interactionEngine.getInputs();
    }

    /**
    * Returns a normalized key name for a form field selector or name.
    * Removes pound signs (#) from selectors.
    *
    * @element The selector or name of an form field.
    *
    * @return string
    */
    private string function generateInputKey(required string element) {
        return replaceNoCase(arguments.element, '##', '', 'all');
    }

    /**
    * Store values found in the parsed form in the in-memory input struct.
    *
    * @pageForm The form jsoup node. [org.jsoup.nodes.Element]
    *
    * @return string
    */
    private void function extractValuesFromForm(required pageForm) {
        var inputs = pageForm.select('[name]');

        for (var input in inputs) {
            variables.interactionEngine.storeInput(
                element = input.attr('name'),
                value = input.val(),
                overwrite = false
            );
        }

        return;
    }


    /**************************** Debug Methods ******************************/


    /**
    * Pipes the html of the page to the debug() output
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function debugPage() {
        variables.DOMAssertionEngine.debugPage();

        return this;
    }

    /**
    * Pipes the framework event to the debug() output
    *
    * @return Integrated.BaseSpecs.AbstractBaseSpec
    */
    public AbstractBaseSpec function debugEvent() {
        variables.frameworkAssertionEngine.debugEvent();

        return this;
    }


    /**************************** Finder Methods ******************************/


    /**
    * Returns the select fields found with a given selector or name.
    * Throws if no select elements are found with the given selector or name.
    *
    * @selectorOrName The selector or name for which to search.
    * @errorMessage The error message to throw if an assertion fails.
    *
    * @throws TestBox.AssertionFailed
    * @return org.jsoup.select.Elements
    */
    private function findSelectField(
        required string selectorOrName,
        string errorMessage = 'Failed to find a [#arguments.selectorOrName#] select field on the page.'
    ) {
        var elements = findElement(arguments.selectorOrName, arguments.errorMessage);

        var selectFields = elements.select('select');

        expect(selectFields).notToBeEmpty(arguments.errorMessage);

        return selectFields;
    }

    /**
    * Returns the checkboxes found with a given selector or name.
    * Throws if no checkboxes are found with the given selector or name.
    *
    * @selectorOrName The selector or name for which to search.
    * @errorMessage The error message to throw if an assertion fails.
    *
    * @throws TestBox.AssertionFailed
    * @return org.jsoup.select.Elements
    */
    private function findCheckbox(
        required string selectorOrName,
        string errorMessage = 'Failed to find a [#arguments.selectorOrName#] checkbox on the page.'
    ) {
        var fields = findElement(arguments.selectorOrName, arguments.errorMessage);

        // Filter down to checkboxes
        var checkboxes = fields.select('[type=checkbox]');

        expect(checkboxes).notToBeEmpty(arguments.errorMessage);

        return checkboxes;
    }
}