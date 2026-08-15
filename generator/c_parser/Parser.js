// https://slebok.github.io/zoo/c/c99/iso-9899-tc3/extracted/index.html
// https://learn.microsoft.com/en-us/cpp/c-language/c-language-reference?view=msvc-170

const {LineComment} = require("./symbols/LineComment");
const {BlockComment} = require("./symbols/BlockComment");

const {ArgumentListExpression} = require("./symbols/ArgumentListExpression");
const {ArrayExpression} = require("./symbols/ArrayExpression");
const {ArrowExpression} = require("./symbols/ArrowExpression");
const {AssignmentExpression} = require("./symbols/AssignmentExpression");
const {BracketExpression} = require("./symbols/BracketExpression");
const {BreakStatement} = require("./symbols/BreakStatement");
const {CaseLabeledStatement} = require("./symbols/CaseLabeledStatement");
const {CastExpression} = require("./symbols/CastExpression");
const {CompoundStatement} = require("./symbols/CompoundStatement");
const {ConditionalExpression} = require("./symbols/ConditionalExpression");
const {ConstantDesignator} = require("./symbols/ConstantDesignator");
const {Constant} = require("./symbols/Constant");
const {ContinueStatement} = require("./symbols/ContinueStatement");
const {Declaration} = require("./symbols/Declaration");
const {DeclaratorExpression} = require("./symbols/DeclaratorExpression");
const {Declarator} = require("./symbols/Declarator");
const {DefaultLabeledStatement} = require("./symbols/DefaultLabeledStatement");
const {DesignationInitializer} = require("./symbols/DesignationInitializer");
const {Designation} = require("./symbols/Designation");
const {DoWhileStatement} = require("./symbols/DoWhileStatement");
const {Enumerator} = require("./symbols/Enumerator");
const {Enum} = require("./symbols/Enum");
const {ExpressionStatement} = require("./symbols/ExpressionStatement");
const {Expression} = require("./symbols/Expression");
const {ForStatement} = require("./symbols/ForStatement");
const {FunctionDefinition} = require("./symbols/FunctionDefinition");
const {GotoStatement} = require("./symbols/GotoStatement");
const {IdentifierDesignator} = require("./symbols/IdentifierDesignator");
const {IdentifierLabeledStatement} = require("./symbols/IdentifierLabeledStatement");
const {IdentifierListExpression} = require("./symbols/IdentifierListExpression");
const {Identifier} = require("./symbols/Identifier");
const {IfStatement} = require("./symbols/IfStatement");
const {InitDeclarator} = require("./symbols/InitDeclarator");
const {InitializerExpression} = require("./symbols/InitializerExpression");
const {LogicalExpression} = require("./symbols/LogicalExpression");
const {OperatorExpression} = require("./symbols/OperatorExpression");
const {ParameterDeclaration} = require("./symbols/ParameterDeclaration");
const {ParameterTypeListExpression} = require("./symbols/ParameterTypeListExpression");
const {ParenthesisExpression} = require("./symbols/ParenthesisExpression");
const {Pointer} = require("./symbols/Pointer");
const {PostfixExpression} = require("./symbols/PostfixExpression");
const {ReturnStatement} = require("./symbols/ReturnStatement");
const {SequenceExpression} = require("./symbols/SequenceExpression");
const {StringLiteralList} = require("./symbols/StringLiteralList");
const {StringLiteral} = require("./symbols/StringLiteral");
const {StructDeclaration} = require("./symbols/StructDeclaration");
const {StructDeclarator} = require("./symbols/StructDeclarator");
const {StructOrUnionSpecifier} = require("./symbols/StructOrUnionSpecifier");
const {SwitchStatement} = require("./symbols/SwitchStatement");
const {Translationunit} = require("./symbols/Translationunit");
const {TypeNameExpression} = require("./symbols/TypeNameExpression");
const {TypeNameInitializerExpression} = require("./symbols/TypeNameInitializerExpression");
const {TypeName} = require("./symbols/TypeName");
const {UnaryExpression} = require("./symbols/UnaryExpression");
const {VariadicParameter} = require("./symbols/VariadicParameter");
const {VisibilityStatement} = require("./symbols/VisibilityStatement");
const {WhileStatement} = require("./symbols/WhileStatement");

const noSpaceReg = /\S/g;
const noWordReg = /\W/g;
const preprocessedLineReg = /^#(?:line)? \d+ "([^"]+)"[^\n]*\n/g;
const pragmaReg = /^#pragma[^\n]+/g;

// https://learn.microsoft.com/en-us/cpp/c-language/c-floating-point-constants?view=msvc-170
const floatingPointConstantReg = (() => {
    const digitSequence = "[0-9]+";
    const fractionalConstant = `(?:${ [
        `${ digitSequence }?\\.${ digitSequence }`,
        `${ digitSequence }\\.`,
    ].join("|") })`;
    const exponentPart = `(?:[Ee][+-]?${ digitSequence })`;
    const floatingSuffix = "[flFL]";

    return new RegExp(`^(?:${ [
        `${ fractionalConstant }${ exponentPart }?${ floatingSuffix }?`,
        `${ digitSequence }${ exponentPart }${ floatingSuffix }?`,
    ].join("|") })`.replaceAll("+?", "*"));
})();

// https://learn.microsoft.com/en-us/cpp/c-language/c-integer-constants?view=msvc-170
const integerConstantReg = (() => {
    const unsignedSuffix = "[uU]";
    const longSuffix = "[lL]";
    const longLongSuffix = "(?:ll|LL)";
    const _64BitIntegerSuffix = "[iI]64";

    const integerSuffix = `(?:${ [
        `${ unsignedSuffix }${ _64BitIntegerSuffix }`,
        `${ unsignedSuffix }${ longLongSuffix }`,
        `${ unsignedSuffix }${ longSuffix }?`,
        `${ longLongSuffix }${ unsignedSuffix }?`,
        `${ longSuffix }${ unsignedSuffix }?`,
        `${ _64BitIntegerSuffix }`,
    ].join("|") })`;

    const hexadecimalDigit = "[0-9a-fA-F]";
    const hexadecimalPrefix = "0[xX]";

    const decimalConstant = "(?:[1-9][0-9]*)";
    const octalConstant = "(?:0[0-7]*)";
    const hexadecimalConstant = `(?:${ hexadecimalPrefix }${ hexadecimalDigit }+)`;

    return new RegExp(`^(?:${ [
        `${ decimalConstant }${ integerSuffix }?`,
        `${ hexadecimalConstant }${ integerSuffix }?`,
        `${ octalConstant }${ integerSuffix }?`,
    ].join("|") })`.replaceAll("+?", "*"));
})();

// https://learn.microsoft.com/en-us/cpp/c-language/c-character-constants?view=msvc-170
const characterConstantReg = (() => {
    // https://learn.microsoft.com/en-us/cpp/c-language/escape-sequences?view=msvc-170
    const simpleEscapeSequence = /[abfnrtv'"\\?]/.source;
    const octalEscapeSequence = /[0-7]{1,3}/.source;
    const hexadecimalEscapeSequence = /x[0-9a-fA-F]+/.source;

    const escapeSequence = `${ /\\/.source }(?:${ [
        `${ simpleEscapeSequence }`,
        `${ octalEscapeSequence }`,
        `${ hexadecimalEscapeSequence }`,
    ].join("|") })`;

    const cchar = /[^\\'\n]/.source;

    return new RegExp(`^L?'(?:${ escapeSequence }|${ cchar })+'`.replaceAll("+?", "*"));
})();

// https://learn.microsoft.com/en-us/cpp/c-language/c-string-literals?view=msvc-170
const stringLiteralConstantReg = (() => {
    // https://learn.microsoft.com/en-us/cpp/c-language/escape-sequences?view=msvc-170
    const simpleEscapeSequence = /[abfnrtv'"\\?]/.source;
    const octalEscapeSequence = /[0-7]{1,3}/.source;
    const hexadecimalEscapeSequence = /x[0-9a-fA-F]+/.source;

    const escapeSequence = `${ /\\/.source }(?:${ [
        `${ simpleEscapeSequence }`,
        `${ octalEscapeSequence }`,
        `${ hexadecimalEscapeSequence }`,
        /\\\n/.source,
    ].join("|") })`;

    const schar = /[^\\"\n]/.source;

    return new RegExp(`^L?"(?:${ escapeSequence }|${ schar })*"`.replaceAll("+?", "*"));
})();

class Parser {
    parse(input, options = {}) {
        this.input = input;
        this.len = input.length;
        this.pos = 0;
        this.lastIndex = 0;
        this.states = [];
        this.comments = new Map();

        this.typedefs = new Set([
            "void",
            "char",
            "short",
            "int",
            "long",
            "float",
            "double",
            "signed",
            "unsigned",
            "_Bool",
            "_Complex",

            // https://en.cppreference.com/w/cpp/language/types
            "signed char",
            "unsigned char",
            "short int",
            "signed short",
            "signed short int",
            "unsigned short",
            "unsigned short int",
            "short unsigned int",
            "signed int",
            "unsigned int",
            "long int",
            "signed long",
            "signed long int",
            "unsigned long",
            "unsigned long int",
            "long unsigned int",
            "long long",
            "long long int",
            "signed long long",
            "signed long long int",
            "unsigned long long",
            "unsigned long long int",
            "long long unsigned int",
            "long double",

            // C++
            "bool",
        ]);

        if (options.typedefs) {
            for (const typedef of options.typedefs) {
                this.typedefs.add(typedef);
            }
        }

        const unit = this.maybeTranslationUnit();
        this.consumeCommentOrSpace();

        if (this.pos !== this.len) {
            const {
                lastIndex
            } = this;
            console.log(lastIndex);
            const lines = [0];
            let pos = 0;
            while ((pos = input.indexOf("\n", pos)) !== -1 && pos < lastIndex) {
                lines.push(++pos);
            }
            const start = lines.pop();
            const end = pos === -1 ? lastIndex + 50 : Math.min(lastIndex + 50, pos);
            const space = `${ " ".repeat(lastIndex - start) }^`;
            throw new Error(`Failed to parse '${ options.filename || "stdin" }'.\nUnexpected token at line ${ lines.length + 1 }\n${ input.slice(start, end) }\n${ space }`);
        }

        return unit;
    }

    // translation-unit ::=
    //     external-declaration
    //     translation-unit external-declaration
    maybeTranslationUnit() {
        const declarations = this._maybeExpressionList("maybeExternalDeclaration");

        return new Translationunit(declarations, {
            start: this.pos,
            end: this.len
        });
    }

    // external-declaration ::=
    //     function-definition
    //     declaration
    maybeExternalDeclaration() {
        return this.maybeFunctionDefinition() || this.maybeDeclaration() || this._maybeTokenExpression(";");
    }

    // function-definition ::=
    //     declaration-specifiers declarator declaration-list? compound-statement
    maybeFunctionDefinition() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // declaration-specifiers
        const specifiers = this.maybeDeclarationSpecifiers();
        if (specifiers.length === 0) {
            return this.popState();
        }

        // declarator
        const declarator = this.maybeDeclarator();
        if (!declarator) {
            return this.popState();
        }

        // declaration-list?
        const declarations = this.maybeDeclarationList();

        // compound-statement
        const statement = this.maybeCompoundStatement();
        if (!statement) {
            return this.popState();
        }

        const decl = new FunctionDefinition({
            /* declaration-specifiers */
            specifiers,

            /* declarator */
            declarator,

            /* declarator declaration-list? */
            declarations,

            /* compound-statement */
            statement
        }, {
            start,
            end: this.pos
        });
        return this.popState(decl);
    }

    // declaration-specifiers ::=
    //     storage-class-specifier declaration-specifiers?
    //     type-specifier declaration-specifiers?
    //     type-qualifier declaration-specifiers?
    //     function-specifier declaration-specifiers?
    maybeDeclarationSpecifiers() {
        return this._maybeExpressionList([
            /* storage-class-specifier */
            "maybeStorageClassSpecifier",
            /* type-specifier */
            "maybeTypeSpecifier",
            /* type-qualifier */
            "maybeTypeQualifier",
            /* function-specifier */
            "maybeFunctionSpecifier",
        ]);
    }

    // storage-class-specifier ::=
    //     "typedef"
    //     "extern"
    //     "static"
    //     "auto"
    //     "register"
    maybeStorageClassSpecifier() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const identifier = this.maybeIdentifier();
        if ([
                "typedef",
                "extern",
                "static",
                "auto",
                "register",
            ].includes(identifier.name)) {
            return this.popState(identifier);
        }
        return this.popState();
    }

    // type-specifier ::=
    //     "void"
    //     "char"
    //     "short"
    //     "int"
    //     "long"
    //     "float"
    //     "double"
    //     "signed"
    //     "unsigned"
    //     "_Bool"
    //     "_Complex"
    //     "bool"
    //     struct-or-union-specifier
    //     enum-specifier
    //     typedef-name
    maybeTypeSpecifier() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        // typedef-name
        const typedefName = this.maybeTypedefName();
        if (typedefName) {
            return this.popState(typedefName);
        }

        // struct-or-union-specifier
        const structOrUnionSpecifier = this.maybeStructOrUnionSpecifier();
        if (structOrUnionSpecifier) {
            return this.popState(structOrUnionSpecifier);
        }

        // enum-specifier
        const enumSpecifier = this.maybeEnumSpecifier();
        if (enumSpecifier) {
            return this.popState(enumSpecifier);
        }

        return this.popState();
    }

    // struct-or-union-specifier ::=
    //     struct-or-union identifier? "{" struct-declaration-list "}"
    //     struct-or-union identifier
    maybeStructOrUnionSpecifier() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const loc = {
            start: this.pos
        };

        // struct-or-union
        const specifier = this.maybeStructOrUnion();
        if (!specifier) {
            return this.popState();
        }

        // identifier?
        const identifier = this.maybeIdentifier();

        if (specifier.name === "class" && identifier) {
            this.typedefs.add(identifier.name);
        }

        loc.end = this.pos;

        // "{"
        const open = this._maybeTokenExpression("{");
        if (!open) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = loc.end;

            return this.popState(new StructOrUnionSpecifier({
                specifier, // struct-or-union
                identifier // identifier
            }, loc));
        }

        // struct-declaration-list
        const scope = this.scope;
        this.scope = identifier.name;
        const declarations = this.maybeStructDeclarationList();
        this.scope = scope;
        if (declarations.length === 0) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = loc.end;

            return this.popState(new StructOrUnionSpecifier({
                specifier, // struct-or-union
                identifier // identifier
            }, loc));
        }

        // "}"
        const close = this._maybeTokenExpression("}");
        if (!close) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = loc.end;

            return this.popState(new StructOrUnionSpecifier({
                specifier, // struct-or-union
                identifier // identifier
            }, loc));
        }

        loc.end = this.pos;
        return this.popState(new StructOrUnionSpecifier({
            specifier, // struct-or-union
            identifier, // identifier?
            open, // "{"
            declarations, // struct-declaration-list
            close // "}"
        }, loc));
    }

    // struct-or-union ::=
    //     "struct"
    //     "union"
    //     "class"
    maybeStructOrUnion() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const identifier = this.maybeIdentifier();
        if (["struct", "union", "class"].includes(identifier.name)) {
            return this.popState(identifier);
        }
        return this.popState();
    }

    // struct-declaration-list ::=
    //     "public" ":"
    //     "protected" ":"
    //     "private" ":"
    //     struct-declaration
    //     struct-declaration-list struct-declaration
    maybeStructDeclarationList() {
        this.visibility = null;
        return this._maybeExpressionList(["maybeVisibilityStatement", "maybeClassDelaration"]).filter(statement => !(statement instanceof VisibilityStatement));
    }

    // visibility-statement ::=
    //     "public" ":"
    //     "protected" ":"
    //     "private" ":"
    maybeVisibilityStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // identifier
        const identifier = this.maybeIdentifier();
        if (!identifier || !["public", "protected", "private"].includes(identifier.name)) {
            return this.popState();
        }

        // ":"
        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            return this.popState();
        }

        this.visibility = new VisibilityStatement({
            identifier, // identifier
            colon, // ":"
        }, {
            start,
            end: this.pos
        });

        return this.popState(this.visibility);
    }

    // class-declaration ::=
    //     struct-declaration
    //     "virtual"? "~"? declaration-specifiers declarator ";"
    //     "virtual"? "~"? declaration-specifiers declarator "=" "0" ";"
    //     "virtual"? "~"? declaration-specifiers declarator "=" "default" ";"
    //     "virtual"? "~"? declaration-specifiers declarator "=" "delete" ";"
    //     "virtual"? "~"? declaration-specifiers declarator compound-statement ";"?
    maybeClassDelaration() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        if (start >= 2130) {
            debugger;
        }

        const declaration = this.maybeStructDeclaration();
        if (declaration) {
            return this.popState(declaration);
        }

        // "virtual"?
        const virtual = this.maybeIdentifier("virtual");

        // "~"
        const destructor = this._maybeTokenExpression("~");

        // declaration-specifiers?
        const specifiers = this.maybeDeclarationSpecifiers();

        if (specifiers.length === 1 && specifiers[0] instanceof Identifier && specifiers[0].name === this.scope) {
            // assume constructor or destructor
            this.pos = specifiers[0].loc.start;
            specifiers.length = 0;
        }

        // declarator
        const declarator = this.maybeDeclarator();
        if (!declarator) {
            return this.popState();
        }

        const decl = new FunctionDefinition({
            /* virtual */
            virtual,

            /* destructor */
            destructor,

            /* declaration-specifiers */
            specifiers,

            /* declarator */
            declarator,
        }, {
            start,
            end: this.pos
        });

        // compound-statement
        const statement = this.maybeCompoundStatement();
        if (statement) {
            decl.statement = statement;
        }

        // ";"
        let semicolon = this._maybeTokenExpression(";");
        if (semicolon) {
            decl.declarations = [semicolon];
            decl.loc.end = semicolon.loc.end;
            return this.popState(decl);
        }

        if (statement) {
            return this.popState();
        }

        "="
        const equals = this._maybeTokenExpression("=");
        if (!equals) {
            return this.popState();
        }

        // "0"
        // "default"
        // "delete"
        const expression = this.maybeIdentifier();
        if (!["0", "default", "delete"].includes(expression.name)) {
            return this.popState();
        }

        // ";"
        semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        decl.declarations = [equals, expression, semicolon];
        decl.loc.end = semicolon.loc.end;

        return this.popState(decl);
    }

    // struct-declaration ::=
    //     specifier-qualifier-list struct-declarator-list ";"
    maybeStructDeclaration() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // specifier-qualifier-list
        const [qualifiers, types] = this.maybeSpecifierQualifierList();

        if (types.length === 0) {
            return this.popState();
        }

        // struct-declarator-list
        const declarators = this.maybeStructDeclaratorList();
        // https://learn.microsoft.com/en-us/cpp/c-language/union-declarations?view=msvc-170
        // Microsoft Specific
        // Nested unions can be declared anonymously when they're members of another structure or union.
        // if (declarators.length === 0) {
        //     return this.popState();
        // }

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new StructDeclaration({
            visibility: this.visibility, // visibility
            type: types[0], // type-specifier
            qualifiers, // type-qualifier-list
            declarators, // struct-declarator-list
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // specifier-qualifier-list ::=
    //     type-specifier specifier-qualifier-list?
    //     type-qualifier specifier-qualifier-list?
    maybeSpecifierQualifierList() {
        const qualifiers = [];
        const types = [];

        // type-specifier specifier-qualifier-list?
        // type-qualifier specifier-qualifier-list?
        let type, qualifier;
        while ((type = this.maybeTypeSpecifier()) || (qualifier = this.maybeTypeQualifier())) {
            if (type) {
                types.push(type);
            }

            if (qualifier) {
                qualifiers.push(qualifier);
            }

            type = undefined;
            qualifier = undefined;
        }

        if (types.length > 1) {
            // More than one type, move the cursor to the end of the first type and last the end of the last qualifier
            if (qualifiers.length !== 0 && types.at(-1).loc.start <= qualifiers.at(-1).loc.end) {
                return this.popState();
            }

            if (qualifiers.length !== 0) {
                this.pos = Math.max(qualifiers.at(-1).loc.end, types[0].loc.end);
            } else {
                this.pos = types[0].loc.end;
            }

            types.length = 1;
        }

        return [qualifiers, types];
    }

    // type-qualifier ::=
    //     "const"
    //     "restrict"
    //     "volatile"
    maybeTypeQualifier() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        const identifier = this.maybeIdentifier();
        if (["const", "restrict", "volatile"].includes(identifier.name)) {
            return this.popState(identifier);
        }

        return this.popState();
    }

    // struct-declarator-list ::=
    //     struct-declarator
    //     struct-declarator-list "," struct-declarator
    maybeStructDeclaratorList() {
        return this._maybeExpressionList("maybeStructDeclarator", ",");
    }

    // struct-declarator ::=
    //     declarator
    //     declarator? ":" constant-expression
    maybeStructDeclarator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // declarator?
        const declarator = this.maybeDeclarator();

        const {pos} = this;

        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            this.pos = pos;
            // declarator
            return this.popState(declarator);
        }

        // constant-expression
        const expression = this.maybeConstantExpression();
        if (!expression) {
            this.pos = pos;
            // declarator
            return this.popState(declarator);
        }

        return this.popState(new StructDeclarator({
            declarator, // declarator?
            colon, // ":"
            expression // constant-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // declarator ::=
    //     pointer? direct-declarator
    maybeDeclarator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // pointer?
        const pointers = this.maybePointers();

        // direct-declarator
        const declarators = this.maybeDirectDeclarator();
        if (declarators.length === 0) {
            return this.popState();
        }

        if (pointers.length === 0 && declarators.length === 1) {
            return this.popState(declarators[0]);
        }

        return this.popState(new Declarator({
            pointers, // pointer?
            declarators // direct-declarator
        }, {
            start,
            end: this.pos
        }));
    }

    // pointer ::=
    //     "*" type-qualifier-list?
    //     "&" type-qualifier-list?
    //     "*" type-qualifier-list? pointer
    maybePointers() {
        const pointers = [];

        let pointer;
        while ((pointer = this._maybeTokenExpression("*")) || (pointer = this._maybeTokenExpression("&"))) { // eslint-disable-line no-cond-assign
            // type-qualifier-list?
            const qualifiers = this.maybeTypeQualifierList();

            pointers.push(new Pointer({
                pointer, // "*"
                qualifiers // type-qualifier-list?
            }, {
                start: pointer.loc.start,
                end: this.pos
            }));
        }

        return pointers;
    }

    // type-qualifier-list ::=
    //     type-qualifier
    //     type-qualifier-list type-qualifier
    maybeTypeQualifierList() {
        return this._maybeExpressionList("maybeTypeQualifier");
    }

    // direct-declarator ::=
    //     identifier
    //     "(" declarator ")"
    //     direct-declarator "[" type-qualifier-list? assignment-expression? "]"
    //     direct-declarator "[" "static" type-qualifier-list? assignment-expression "]"
    //     direct-declarator "[" type-qualifier-list "static" assignment-expression "]"
    //     direct-declarator "[" type-qualifier-list? "*" "]"
    //     direct-declarator "(" parameter-type-list ")"
    //     direct-declarator "(" identifier-list? ")"
    maybeDirectDeclarator() {
        const declarators = [];

        // identifier
        // "(" declarator ")"
        const top = this.maybeIdentifier() || this.maybeDeclaratorExpression();
        if (!top) {
            return declarators;
        }

        // identifier
        // "(" declarator ")"
        declarators.push(top);

        // "(" declarator ")"
        // direct-declarator "[" type-qualifier-list? assignment-expression? "]"
        // direct-declarator "[" "static" type-qualifier-list? assignment-expression "]"
        // direct-declarator "[" type-qualifier-list "static" assignment-expression "]"
        // direct-declarator "[" type-qualifier-list? "*" "]"
        // direct-declarator "(" parameter-type-list ")"
        // direct-declarator "(" identifier-list? ")"
        let declarator;
        // eslint-disable-next-line no-cond-assign
        while (declarator =
            // "[" type-qualifier-list? assignment-expression? "]"
            // "[" "static" type-qualifier-list? assignment-expression "]"
            // "[" type-qualifier-list "static" assignment-expression "]"
            // "[" type-qualifier-list? "*" "]"
            this.maybeArrayExpression(false)

            // "(" parameter-type-list ")"
            ||
            this.maybeParameterTypeListExpression(false)

            // "(" identifier-list? ")"
            ||
            this.maybeIdentifierListExpression()
        ) {
            declarators.push(declarator);
        }

        return declarators;
    }

    // declarator-expression ::=
    //     "(" declarator ")"
    maybeDeclaratorExpression() {
        return this._maybeDeclaratorExpression("maybeDeclarator");
    }

    // array-expression ::=
    //     "[" type-qualifier-list? assignment-expression? "]"
    //     "[" "static" type-qualifier-list? assignment-expression "]"
    //     "[" type-qualifier-list "static" assignment-expression "]"
    //     "[" type-qualifier-list? "*" "]"
    maybeArrayExpression(allowPointerOnly = true) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "["
        const open = this._maybeTokenExpression("[");
        if (!open) {
            return this.popState();
        }

        // type-qualifier-list?
        const qualifiers = this.maybeTypeQualifierList();

        // "static"
        const storage = this.maybeIdentifier("static");

        if (storage && qualifiers.length === 0) {
            // type-qualifier-list?
            qualifiers.push(...this.maybeTypeQualifierList());
        }

        // assignment-expression
        let expression = this.maybeAssignmentExpression();

        if (storage && !expression) {
            return this.popState();
        }

        if (!storage && !expression) {
            if (allowPointerOnly && qualifiers.length !== 0) {
                return this.popState();
            }

            // "*"
            expression = this._maybeTokenExpression("*");
        }

        // "]"
        const close = this._maybeTokenExpression("]");
        if (!close) {
            return this.popState();
        }

        return this.popState(new ArrayExpression({
            open, // "["
            storage, // "static"
            qualifiers, // type-qualifier-list?
            expression, // assignment-expression || "*" || None
            close // "]"
        }, {
            start,
            end: this.pos
        }));
    }

    // parameter-type-list-expression ::=
    //     "(" parameter-type-list ")"
    maybeParameterTypeListExpression(allowEmpty = true) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "("
        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        // parameter-type-list
        const params = this.maybeParameterTypeList();
        if (!allowEmpty && params.length === 0) {
            return this.popState();
        }

        // ")"
        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new ParameterTypeListExpression({
            open, // "("
            params, // parameter-type-list
            close // ")"
        }, {
            start,
            end: this.pos
        }));
    }

    // identifier-list-expression ::=
    //     "(" identifier-list? ")"
    maybeIdentifierListExpression(allowEmpty = true) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "("
        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        // identifier-list?
        const identifiers = this.maybeIdentifierList();
        if (!allowEmpty && identifiers.length === 0) {
            return this.popState();
        }

        // ")"
        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new IdentifierListExpression({
            open, // "("
            identifiers, // identifier-list?
            close, // ")"
        }, {
            start,
            end: this.pos
        }));
    }

    // assignment-expression ::=
    //     conditional-expression
    //     unary-expression assignment-operator assignment-expression
    maybeAssignmentExpression() {
        return this.maybeUnaryOperatorAssignmentExpression() || this.maybeConditionalExpression();
    }

    // unary-operator-assignment-expression ::=
    //     conditional-expression
    //     unary-expression assignment assignment-expression
    maybeUnaryOperatorAssignmentExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // unary-expression
        const unary = this.maybeUnaryExpression();
        if (!unary) {
            return this.popState();
        }

        // assignment-operator
        const operator = this.maybeAssignmentOperator();
        if (!operator) {
            return this.popState();
        }

        // assignment-expression
        const expression = this.maybeAssignmentExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new AssignmentExpression({
            unary, // unary-expression
            operator, // assignment-operator
            expression // assignment-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // conditional-expression ::=
    //     logical-OR-expression
    //     logical-OR-expression "?" expression ":" conditional-expression
    maybeConditionalExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // logical-OR-expression
        const expression = this.maybeLogicalOrExpression();
        if (!expression) {
            return this.popState();
        }

        const {pos} = this;

        // "?"
        const ternary = this._maybeTokenExpression("?");
        if (!ternary) {
            // logical-OR-expression
            this.pos = pos;
            return this.popState(expression);
        }

        // expression
        const truthy = this.maybeExpression();
        if (!truthy) {
            // logical-OR-expression
            this.pos = pos;
            return this.popState(expression);
        }

        // ":"
        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            // logical-OR-expression
            this.pos = pos;
            return this.popState(expression);
        }

        // conditional-expression
        const falsy = this.maybeConditionalExpression();
        if (!falsy) {
            this.pos = pos;
            return this.popState(expression);
        }

        return this.popState(new ConditionalExpression({
            condition: expression, // logical-OR-expression
            ternary, // "?"
            truthy, // expression
            colon, // ":"
            falsy, // conditional-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // logical-OR-expression ::=
    //     logical-AND-expression
    //     logical-OR-expression "||" logical-AND-expression
    maybeLogicalOrExpression() {
        return this._maybeLogicalExpression(["||"], "maybeLogicalAndExpression");
    }

    // logical-AND-expression ::=
    //     inclusive-OR-expression
    //     logical-AND-expression "&&" inclusive-OR-expression
    maybeLogicalAndExpression() {
        return this._maybeLogicalExpression(["&&"], "maybeInclusiveOrExpression");
    }

    // inclusive-OR-expression ::=
    //     exclusive-OR-expression
    //     inclusive-OR-expression "|" exclusive-OR-expression
    maybeInclusiveOrExpression() {
        return this._maybeLogicalExpression(["|"], "maybeExclusiveOrExpression");
    }

    // exclusive-OR-expression ::=
    //     AND-expression
    //     exclusive-OR-expression "^" AND-expression
    maybeExclusiveOrExpression() {
        return this._maybeLogicalExpression(["^"], "maybeAndExpression");
    }

    // AND-expression ::=
    //     equality-expression
    //     AND-expression "&" equality-expression
    maybeAndExpression() {
        return this._maybeLogicalExpression(["&"], "maybeEqualityExpression");
    }

    // equality-expression ::=
    //     relational-expression
    //     equality-expression "==" relational-expression
    //     equality-expression "!=" relational-expression
    maybeEqualityExpression() {
        return this._maybeLogicalExpression(["==", "!="], "maybeRelationalExpression");
    }

    // relational-expression ::=
    //     shift-expression
    //     relational-expression "<" shift-expression
    //     relational-expression ">" shift-expression
    //     relational-expression "<=" shift-expression
    //     relational-expression ">=" shift-expression
    maybeRelationalExpression() {
        return this._maybeLogicalExpression(["<", ">", "<=", ">="], "maybeShiftExpression");
    }

    // shift-expression ::=
    //     additive-expression
    //     shift-expression "<<" additive-expression
    //     shift-expression ">>" additive-expression
    maybeShiftExpression() {
        return this._maybeLogicalExpression(["<<", ">>"], "maybeAdditiveExpression");
    }

    // additive-expression ::=
    //     multiplicative-expression
    //     additive-expression "+" multiplicative-expression
    //     additive-expression "-" multiplicative-expression
    maybeAdditiveExpression() {
        return this._maybeLogicalExpression(["+", "-"], "maybeMultiplicativeExpression");
    }

    // multiplicative-expression ::=
    //     cast-expression
    //     multiplicative-expression "*" cast-expression
    //     multiplicative-expression "/" cast-expression
    //     multiplicative-expression "%" cast-expression
    maybeMultiplicativeExpression() {
        return this._maybeLogicalExpression(["*", "/", "%"], "maybeCastExpression");
    }

    // cast-expression ::=
    //     unary-expression
    //     "(" type-name ")" cast-expression
    maybeCastExpression() {
        return this.maybeTypeNameCastExpression() || this.maybeUnaryExpression();
    }

    // typename-cast-expression ::=
    //     "(" type-name ")" cast-expression
    maybeTypeNameCastExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "(" type-name ")"
        const type = this.maybeTypeNameExpression();
        if (!type) {
            return this.popState();
        }

        // cast-expression
        const expression = this.maybeCastExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new CastExpression({
            type, // "(" type-name ")"
            expression // cast-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // unary-expression ::=
    //     postfix-expression
    //     "++" unary-expression
    //     "--" unary-expression
    //     unary-operator cast-expression
    //     "sizeof" unary-expression
    //     "sizeof" "(" type-name ")"
    maybeUnaryExpression() {
        return this.maybeIncDecUnaryExpression()
            || this.maySizeofUnaryExpression()
            || this.mayUnaryOperatorCastExpression()
            || this.maybePostfixExpression();
    }

    // inc-dec-unary-expression ::=
    //     "++" unary-expression
    //     "--" unary-expression
    maybeIncDecUnaryExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "++"
        // "--"
        if (!this.input.startsWith("++", this.pos) && !this.input.startsWith("--", this.pos)) {
            return this.popState();
        }

        const operator = new OperatorExpression(this.input.slice(this.pos, this.pos + "++".length), {
            start: this.pos,
            end: this.pos + "++".length
        });
        this.pos = operator.loc.end;

        // unary-expression
        const expression = this.maybeUnaryExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new UnaryExpression({
            operator, // "++" || "--"
            expression // unary-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // unary-operator-cast-expression ::=
    //     unary-operator cast-expression
    mayUnaryOperatorCastExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // unary-operator
        const operator = this.maybeUnaryOperator();
        if (!operator) {
            return this.popState();
        }

        // cast-expression
        const expression = this.maybeCastExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new UnaryExpression({
            operator, // unary-operator
            expression // cast-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // sizeof-unary-expression ::=
    //     "sizeof" unary-expression
    //     "sizeof" "(" type-name ")"
    maySizeofUnaryExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "sizeof"
        const identifier = this.maybeIdentifier("sizeof");
        if (!identifier) {
            return this.popState();
        }
        const sizeof = new OperatorExpression(identifier.name, identifier.loc);

        // unary-expression
        // "(" type-name ")"
        const expression = this.maybeTypeNameExpression() || this.maybeUnaryExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new UnaryExpression({
            operator: sizeof, // "sizeof"
            expression // unary-expression || "(" type-name ")"
        }, {
            start,
            end: this.pos
        }));
    }

    // postfix-expression ::=
    //     primary-expression
    //     postfix-expression "[" expression "]"
    //     postfix-expression "(" argument-expression-list? ")"
    //     postfix-expression "." identifier
    //     postfix-expression "->" identifier
    //     postfix-expression "++"
    //     postfix-expression "--"
    //     "(" type-name ")" "{" initializer-list "}"
    //     "(" type-name ")" "{" initializer-list "," "}"
    maybePostfixExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // primary-expression
        const primary = this.maybePrimaryExpression();
        if (primary) {
            const accessors = this._maybeExpressionList([
                "maybeBracketExpression", // "[" expression "]"
                "maybeArgumentExpressionListExpression", // "(" argument-expression-list? ")"
                "maybeIdentifierDesignator", // "." identifier
                "maybeArrowExpression", // "->" identifier
                "maybeIncDecExpression", // "++" || "--"
            ]);

            if (accessors.length === 0) {
                return this.popState(primary);
            }

            return this.popState(new PostfixExpression({
                // primary-expression
                primary,

                // postfix-expression "[" expression "]"
                // postfix-expression "(" argument-expression-list? ")"
                // postfix-expression "." identifier
                // postfix-expression "->" identifier
                // postfix-expression "++"
                // postfix-expression "--"
                accessors
            }, {
                start,
                end: this.pos
            }));
        }

        // "(" type-name ")"
        const typename = this.maybeTypeNameExpression();
        if (!typename) {
            return this.popState();
        }

        // "{" initializer-list "}"
        // "{" initializer-list "," "}"
        const expression = this.maybeInitializerListExpression();
        if (!expression) {
            return this.popState();
        }

        return this.popState(new TypeNameInitializerExpression({
            // "(" type-name ")"
            typename,

            // "{" initializer-list "}"
            // "{" initializer-list "," "}"
            expression
        }, {
            start,
            end: this.pos
        }));
    }

    // bracket-expression ::=
    //     "[" expression "]"
    maybeBracketExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("[");
        if (!open) {
            return this.popState();
        }

        const expression = this.maybeExpression();
        if (!expression) {
            return this.popState();
        }

        const close = this._maybeTokenExpression("]");
        if (!close) {
            return this.popState();
        }

        return this.popState(new BracketExpression({
            open,
            expression,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // argument-expression-list-expression ::=
    //     "(" argument-expression-list? ")"
    maybeArgumentExpressionListExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        const args = this.maybeArgumentExpressionList();

        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new ArgumentListExpression({
            open,
            args,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // arrow-expression ::=
    //     "->" identifier
    maybeArrowExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const arrow = this._maybeTokenExpression("->");
        if (!arrow) {
            return this.popState();
        }

        const identifier = this.maybeIdentifier();
        if (!identifier) {
            return this.popState();
        }

        return this.popState(new ArrowExpression({
            arrow,
            identifier
        }, {
            start,
            end: this.pos
        }));
    }

    // inc-dec-expression ::=
    //     "++"
    //     "--"
    maybeIncDecExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        if (!this.input.startsWith("++", this.pos) && !this.input.startsWith("--", this.pos)) {
            return this.popState();
        }
        const operator = this.input.slice(this.pos, this.pos + "++".length);
        this.pos += operator.length;

        return this.popState(new OperatorExpression(operator, {
            start: this.pos - operator.length,
            end: this.pos
        }));
    }

    // primary-expression ::=
    //     identifier
    //     constant
    //     string-literal
    //     "(" expression ")"
    maybePrimaryExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        // constant
        const constant = this.maybeConstant();
        if (constant) {
            return this.popState(constant);
        }

        // string-literal
        const literal = this.maybeStringLiteral();
        if (literal) {
            return this.popState(literal);
        }

        // identifier
        const identifier = this.maybeIdentifier();
        if (identifier) {
            return this.popState(identifier);
        }

        // "(" expression ")"
        const expression = this.maybeParenthesisExpression();
        return this.popState(expression);
    }

    // parenthesis-expression ::=
    //     "(" expression ")"
    maybeParenthesisExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        const expression = this.maybeExpression();
        if (!expression) {
            return this.popState();
        }

        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new ParenthesisExpression({
            open,
            expression,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // expression ::=
    //     assignment-expression
    //     expression "," assignment-expression
    maybeExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const expressions = this._maybeExpressionList("maybeAssignmentExpression", ",");
        if (expressions.length === 0) {
            return this.popState();
        }

        if (expressions.length === 1) {
            return this.popState(expressions[0]);
        }

        return this.popState(new SequenceExpression(expressions, {
            start,
            end: this.pos
        }));
    }

    // argument-expression-list ::=
    //     assignment-expression
    //     argument-expression-list "," assignment-expression
    maybeArgumentExpressionList() {
        return this._maybeExpressionList("maybeAssignmentExpression", ",");
    }

    // type-name ::=
    //     specifier-qualifier-list abstract-declarator?
    maybeTypeName() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // specifier-qualifier-list
        const [qualifiers, types] = this.maybeSpecifierQualifierList();

        // abstract-declarator?
        const declarator = this.maybeAbstractDeclarator();

        return this.popState(new TypeName({
            qualifiers, // type-qualifier-list
            type: types[0], // type-specifier
            declarator // abstract-declarator?
        }, {
            start,
            end: this.pos
        }));
    }

    // abstract-declarator ::=
    //     pointer
    //     pointer? direct-abstract-declarator
    maybeAbstractDeclarator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // pointer?
        const pointers = this.maybePointers();

        // direct-abstract-declarator
        const declarator = this.maybeDirectAbstractDeclarator();

        if (pointers.length === 0) {
            return this.popState(declarator);
        }

        return this.popState(new Declarator({
            pointers,
            declarators: declarator ? [declarator] : []
        }, {
            start,
            end: this.pos
        }));
    }

    // direct-abstract-declarator ::=
    //     "(" abstract-declarator ")"
    //     direct-abstract-declarator? "[" type-qualifier-list? assignment-expression? "]"
    //     direct-abstract-declarator? "[" "static" type-qualifier-list? assignment-expression "]"
    //     direct-abstract-declarator? "[" type-qualifier-list "static" assignment-expression "]"
    //     direct-abstract-declarator? "[" "*" "]"
    //     direct-abstract-declarator? "(" parameter-type-list? ")"
    maybeDirectAbstractDeclarator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const expressions = [];

        // "(" abstract-declarator ")"
        const expression = this.maybeAbstractDeclaratorExpression();

        if (expression) {
            expressions.push(expression);
        }

        // "[" type-qualifier-list? assignment-expression? "]"
        // "[" "static" type-qualifier-list? assignment-expression "]"
        // "[" type-qualifier-list "static" assignment-expression "]"
        // "[" "*" "]"
        // "(" parameter-type-list? ")"
        expressions.push(...this._maybeExpressionList([
            // "[" type-qualifier-list? assignment-expression? "]"
            // "[" "static" type-qualifier-list? assignment-expression "]"
            // "[" type-qualifier-list "static" assignment-expression "]"
            // "[" "*" "]"
            "maybeArrayExpression",

            // "(" parameter-type-list? ")"
            "maybeParameterTypeListExpression",
        ]));

        if (expressions.length === 0) {
            return this.popState();
        }

        if (expressions.length === 1) {
            return this.popState(expressions[0]);
        }

        return this.popState(new SequenceExpression(expressions, {
            start,
            end: this.pos
        }));
    }

    // abstract-declarator-expression ::=
    //     "(" abstract-declarator ")"
    maybeAbstractDeclaratorExpression() {
        return this._maybeDeclaratorExpression("maybeAbstractDeclarator");
    }

    // parameter-type-list ::=
    //     parameter-list
    //     parameter-list "," "..."
    maybeParameterTypeList() {
        const params = this.maybeParameterList();
        const {pos} = this;

        const comma = this._maybeTokenExpression(",");
        if (!comma) {
            this.pos = pos;
            return params;
        }

        const variadic = this._maybeTokenExpression("...");
        if (!variadic) {
            this.pos = pos;
            return params;
        }

        params.push(new VariadicParameter({
            comma,
            variadic
        }, {
            start: comma.loc.start,
            end: variadic.loc.start
        }));

        return params;
    }

    // parameter-list ::=
    //     parameter-declaration
    //     parameter-list "," parameter-declaration
    maybeParameterList() {
        return this._maybeExpressionList("maybeParameterDeclaration", ",");
    }

    // parameter-declaration ::=
    //     declaration-specifiers declarator
    //     declaration-specifiers declarator "=" initialzer
    //     declaration-specifiers abstract-declarator?
    maybeParameterDeclaration() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // declaration-specifiers
        const specifiers = this.maybeDeclarationSpecifiers();
        if (specifiers.length === 0) {
            return this.popState();
        }

        // declarator
        // abstract-declarator?
        const declarator = this.maybeDeclarator() || this.maybeAbstractDeclarator();

        const {pos} = this;

        // "=" initialzer
        let equals = this._maybeTokenExpression("=");
        let initializer = null;
        if (equals) {
            initializer = this.maybeInitializer();
        }

        if (!initializer) {
            this.pos = pos;
            equals = null;
        }

        return this.popState(new ParameterDeclaration({
            specifiers, // declaration-specifiers
            declarator, // declarator || abstract-declarator?
            equals, // "="
            initializer, // initializer
        }, {
            start,
            end: this.pos
        }));
    }

    // initializer-list ::=
    //     designation? initializer
    //     initializer-list "," designation? initializer
    maybeInitializerList() {
        return this._maybeExpressionList("maybeDesignationInitializer", ",");
    }

    // designation-initializer ::=
    //     designation? initializer
    maybeDesignationInitializer() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // designation?
        const designation = this.maybeDesignation();

        // initializer
        const initializer = this.maybeInitializer();
        if (!initializer) {
            return this.popState();
        }

        if (!designation) {
            return this.popState(initializer);
        }

        return this.popState(new DesignationInitializer({
            designation,
            initializer
        }, {
            start,
            end: this.pos
        }));
    }

    // designation ::=
    //     designator-list "="
    maybeDesignation() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // designator-list
        const designators = this.maybeDesignatorList();
        if (designators.length === 0) {
            return this.popState();
        }

        // "="
        const equals = this._maybeTokenExpression("=");
        if (!equals) {
            return this.popState();
        }

        return this.popState(new Designation({
            designators, // designator-list
            equals // "="
        }, {
            start,
            end: this.pos
        }));
    }

    // designator-list ::=
    //     designator
    //     designator-list designator
    maybeDesignatorList() {
        return this._maybeExpressionList("maybeDesignator");
    }

    // designator ::=
    //     "[" constant-expression "]"
    //     "." identifier
    maybeDesignator() {
        return this.maybeConstantDesignator() || this.maybeIdentifierDesignator();
    }

    // constant-designator ::=
    //     "[" constant-expression "]"
    maybeConstantDesignator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("[");
        if (!open) {
            return this.popState();
        }

        const expression = this.maybeConstantExpression();
        if (!expression) {
            return this.popState();
        }

        const close = this._maybeTokenExpression("]");
        if (!close) {
            return this.popState();
        }

        return this.popState(new ConstantDesignator({
            open,
            expression,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // identifier-designator ::=
    //     "." identifier
    maybeIdentifierDesignator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const dot = this._maybeTokenExpression(".");
        if (!dot) {
            return this.popState();
        }

        const identifier = this.maybeIdentifier();
        if (!identifier) {
            return this.popState();
        }

        return this.popState(new IdentifierDesignator({
            dot,
            identifier
        }, {
            start,
            end: this.pos
        }));
    }

    // constant-expression ::=
    //     conditional-expression
    maybeConstantExpression() {
        return this.maybeConditionalExpression();
    }

    // initializer ::=
    //     assignment-expression
    //     "{" initializer-list "}"
    //     "{" initializer-list "," "}"
    maybeInitializer() {
        return this.maybeAssignmentExpression() || this.maybeInitializerListExpression();
    }

    // unary-operator ::=
    //     "&"
    //     "*"
    //     "+"
    //     "-"
    //     "~"
    //     "!"
    maybeUnaryOperator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        const operator = this.input[this.pos];
        if (![
                "&",
                "*",
                "+",
                "-",
                "~",
                "!",
            ].includes(operator)) {
            return this.popState();
        }

        this.pos += operator.length;

        return this.popState(new OperatorExpression(operator, {
            start: this.pos - operator.length,
            end: this.pos
        }));
    }

    // type-name-expression ::=
    //     "(" type-name ")"
    maybeTypeNameExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        const type = this.maybeTypeName();
        if (!type) {
            return this.popState();
        }

        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new TypeNameExpression({
            open,
            type,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // assignment-operator ::=
    //     "="
    //     "*="
    //     "/="
    //     "%="
    //     "+="
    //     "-="
    //     "<<="
    //     ">>="
    //     "&="
    //     "^="
    //     "|="
    maybeAssignmentOperator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        for (const operator of [
                "=",
                "*=",
                "/=",
                "%=",
                "+=",
                "-=",
                "<<=",
                ">>=",
                "&=",
                "^=",
                "|=",
            ]) {
            if (this.input.startsWith(operator, this.pos)) {
                this.pos += operator.length;
                return this.popState(new OperatorExpression(operator, {
                    start: this.pos - operator.length,
                    end: this.pos
                }));
            }
        }

        return this.popState();
    }

    // initializer-list-expression ::=
    //     "{" initializer-list "}"
    //     "{" initializer-list "," "}"
    maybeInitializerListExpression() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("{");
        if (!open) {
            return this.popState();
        }

        const initializers = this.maybeInitializerList();
        if (initializers.length === 0) {
            return this.popState();
        }

        const comma = this._maybeTokenExpression(",");

        const close = this._maybeTokenExpression("}");
        if (!close) {
            return this.popState();
        }

        return this.popState(new InitializerExpression({
            open,
            initializers,
            comma,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    // identifier-list ::=
    //     identifier
    //     identifier-list "," identifier
    maybeIdentifierList() {
        return this._maybeExpressionList("maybeIdentifier", ",");
    }

    // enum-specifier ::=
    //     "enum" identifier? "{" enumerator-list "}"
    //     "enum" identifier? "{" enumerator-list "," "}"
    //     "enum" identifier
    maybeEnumSpecifier() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "enum"
        const enumkw = this.maybeIdentifier("enum");
        if (!enumkw) {
            return this.popState();
        }

        // identifier?
        const identifier = this.maybeIdentifier();

        const {pos} = this;

        // "{"
        const open = this._maybeTokenExpression("{");
        if (!open) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = pos;
            return this.popState(new Enum({
                enumkw, // "enum"
                identifier // identifier
            }, {
                start,
                end: this.pos
            }));
        }

        // enumerator-list
        const enumerators = this.maybeEnumeratorList();
        if (enumerators.length === 0) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = pos;
            return this.popState(new Enum({
                enumkw, // "enum"
                identifier // identifier
            }, {
                start,
                end: this.pos
            }));
        }

        // ","?
        const comma = this._maybeTokenExpression(",");

        // "}"
        const close = this._maybeTokenExpression("}");
        if (!close) {
            if (!identifier) {
                return this.popState();
            }

            this.pos = pos;
            return this.popState(new Enum({
                enumkw, // "enum"
                identifier // identifier
            }, {
                start,
                end: this.pos
            }));
        }

        return this.popState(new Enum({
            enumkw, // "enum"
            identifier, // identifier?
            open, // "{"
            enumerators, // enumerator-list
            comma, // ","?
            close // "}"
        }, {
            start,
            end: this.pos
        }));
    }

    // enumerator-list ::=
    //     enumerator
    //     enumerator-list "," enumerator
    maybeEnumeratorList() {
        return this._maybeExpressionList("maybeEnumerator", ",");
    }

    // enumerator ::=
    //     enumeration-constant
    //     enumeration-constant "=" constant-expression
    maybeEnumerator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // enumeration-constant
        const identifier = this.maybeIdentifier();
        if (!identifier) {
            return this.popState();
        }

        const {pos} = this;

        // "="
        const equals = this._maybeTokenExpression("=");
        if (!equals) {
            this.pos = pos;
            // enumeration-constant
            return this.popState(identifier);
        }

        // constant-expression
        const expression = this.maybeConstantExpression();
        if (!expression) {
            this.pos = pos;
            // enumeration-constant
            return this.popState(identifier);
        }

        return this.popState(new Enumerator({
            identifier, // enumeration-constant
            equals, // "="
            expression // constant-expression
        }, {
            start,
            end: this.pos
        }));
    }

    // typedef-name ::=
    //     identifier
    maybeTypedefName() {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        const identifiers = [];

        for (let i = 0; i < 4; i++) {
            const identifier = this.maybeIdentifier();
            if (!identifier) {
                break;
            }
            identifiers.push(identifier);
        }

        for (let i = identifiers.length; i > 0; i--) {
            const name = identifiers.slice(0, i).map(identifier => identifier.name).join(" ");
            if (this.typedefs.has(name)) {
                const start = identifiers[0].loc.start;
                const end = identifiers[i - 1].loc.end;
                this.pos = end;
                return this.popState(new Identifier(name, {
                    start,
                    end
                }));
            }
        }

        return this.popState();
    }

    // function-specifier ::=
    //     "inline"
    maybeFunctionSpecifier() {
        return this.maybeIdentifier("inline");
    }

    // declaration-list ::=
    //     declaration
    //     declaration-list declaration
    maybeDeclarationList() {
        return this._maybeExpressionList("maybeDeclaration");
    }

    // declaration ::=
    //     declaration-specifiers init-declarator-list? ";"
    maybeDeclaration(withsemi = true) {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        const start = this.pos;

        // declaration-specifiers
        const specifiers = this.maybeDeclarationSpecifiers();
        if (specifiers.length === 0) {
            return this.popState();
        }

        // init-declarator-list?
        const declarators = this.maybeInitDeclaratorList();

        if (
            specifiers[0].name === "typedef"
            && declarators.length === 0
            && specifiers.at(-1) instanceof Identifier
            && this.typedefs.has(specifiers.at(-1).name)
        ) {
            // Attempt redeclaration of typedef
            const declarator = specifiers.pop();
            this.pos = declarator.loc.start;
            declarators.push(...this.maybeInitDeclaratorList());
        }

        let semicolon;
        if (withsemi) {
            semicolon = this._maybeTokenExpression(";");
            if (!semicolon) {
                return this.popState();
            }

            // add to typedefs typedef declarator[, declarator ...] ";"
            if (specifiers[0].name === "typedef" && declarators.length !== 0) {
                for (let declarator of declarators) {
                    while (declarator instanceof DeclaratorExpression) {
                        declarator = declarator.declarator;
                    }

                    // typedef ... identifier ";"
                    if (declarator instanceof Identifier) {
                        this.typedefs.add(declarator.name);
                        continue;
                    }

                    // typedef ... "*" identifier[...] ";"
                    if (
                        declarator instanceof Declarator
                        && declarator.declarators.length !== 0
                        && declarator.declarators[0] instanceof Identifier
                        && declarator.declarators.slice(1).every(decl => decl instanceof ArrayExpression)
                    ) {
                        this.typedefs.add(declarator.declarators[0].name);
                        continue;
                    }

                    if (
                        declarator instanceof Declarator
                        && declarator.declarators.length === 2
                        && (
                            declarator.declarators[1] instanceof ParameterTypeListExpression
                            || declarator.declarators[1] instanceof IdentifierListExpression && declarator.declarators[1].identifiers.length === 0
                        )
                    ) {
                        let decl = declarator.declarators[0];
                        while (decl instanceof DeclaratorExpression) {
                            decl = decl.declarator;
                        }

                        // typedef pointer? identifier "(" parameter-type-list? ")" ";"
                        if (decl instanceof Identifier) {
                            this.typedefs.add(decl.name);
                            continue;
                        }

                        // typedef "(" declarator ")" "(" parameter-type-list ")" ";"
                        if (
                            decl instanceof Declarator
                            && decl.declarators.length === 1
                            && decl.declarators[0] instanceof Identifier
                        ) {
                            this.typedefs.add(decl.declarators[0].name);
                            continue;
                        }
                    }

                    // unhandled typedef case
                    // debugger;
                }
            }
        }

        return this.popState(new Declaration({
            specifiers, // declaration-specifiers
            declarators, // init-declarator-list?
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // init-declarator-list ::=
    //     init-declarator
    //     init-declarator-list "," init-declarator
    maybeInitDeclaratorList() {
        return this._maybeExpressionList("maybeInitDeclarator", ",");
    }

    // init-declarator ::=
    //     declarator
    //     declarator "=" initializer
    maybeInitDeclarator() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // declarator
        const declarator = this.maybeDeclarator();
        if (!declarator) {
            return this.popState();
        }

        const {pos} = this;

        // "="
        const equals = this._maybeTokenExpression("=");
        if (!equals) {
            this.pos = pos;
            return this.popState(declarator);
        }

        // initializer
        const initializer = this.maybeInitializer();
        if (!initializer) {
            this.pos = pos;
            return this.popState(declarator);
        }

        return this.popState(new InitDeclarator({
            declarator, // declarator
            equals, // "="
            initializer // initializer
        }, {
            start,
            end: this.pos
        }));
    }

    // compound-statement ::=
    //     "{" block-item-list? "}"
    maybeCompoundStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "{"
        const open = this._maybeTokenExpression("{");
        if (!open) {
            return this.popState();
        }

        // block-item-list?
        const blocks = this.maybeBlockItemList();

        // "}"
        const close = this._maybeTokenExpression("}");
        if (!close) {
            return this.popState();
        }

        return this.popState(new CompoundStatement({
            open, // "{"
            blocks, // block-item-list?
            close // "}"
        }, {
            start,
            end: this.pos
        }));
    }

    // block-item-list ::=
    //     block-item
    //     block-item-list block-item
    maybeBlockItemList() {
        return this._maybeExpressionList("maybeBlockItem");
    }

    // block-item ::=
    //     declaration
    //     statement
    maybeBlockItem() {
        return this.maybeDeclaration() || this.maybeStatement();
    }

    // statement ::=
    //     labeled-statement
    //     compound-statement
    //     expression-statement
    //     selection-statement
    //     iteration-statement
    //     jump-statement
    maybeStatement() {
        return this.maybeLabeledStatement() ||
            this.maybeCompoundStatement() ||
            this.maybeSelectionStatement() ||
            this.maybeIterationStatement() ||
            this.maybeJumpStatement() ||
            this.maybeExpressionStatement();
    }

    // labeled-statement ::=
    //     identifier ":" statement
    //     "case" constant-expression ":" statement
    //     "default" ":" statement
    maybeLabeledStatement() {
        return this.maybeDefaultLabeledStatement() ||
            this.maybeCaseLabeledStatement() ||
            this.maybeIdentifierLabeledStatement();
    }

    // identifier-labeled-statement ::=
    //     identifier ":" statement
    maybeIdentifierLabeledStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // identifier
        const identifier = this.maybeIdentifier();
        if (!identifier) {
            return this.popState();
        }

        // ":"
        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new IdentifierLabeledStatement({
            identifier, // identifier
            colon, // ":"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // case-labeled-statement ::=
    //     "case" constant-expression ":" statement
    maybeCaseLabeledStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "case"
        const identifier = this.maybeIdentifier("case");
        if (!identifier) {
            return this.popState();
        }

        // constant-expression
        const expression = this.maybeConstantExpression();
        if (!expression) {
            return this.popState();
        }

        // ":"
        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new CaseLabeledStatement({
            identifier, // "case"
            expression, // constant-expression
            colon, // ":"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // default-labeled-statement ::=
    //     "default" ":" statement
    maybeDefaultLabeledStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "default"
        const identifier = this.maybeIdentifier("default");
        if (!identifier) {
            return this.popState();
        }

        // ":"
        const colon = this._maybeTokenExpression(":");
        if (!colon) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new DefaultLabeledStatement({
            identifier, // "default"
            colon, // ":"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // expression-statement ::=
    //     expression? ";"
    maybeExpressionStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // expression?
        const expression = this.maybeExpression();

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        if (!expression) {
            // ";"
            return this.popState(semicolon);
        }

        return this.popState(new ExpressionStatement({
            expression, // expression
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // selection-statement ::=
    //     "if" "(" expression ")" statement
    //     "if" "(" expression ")" statement "else" statement
    //     "switch" "(" expression ")" statement
    maybeSelectionStatement() {
        return this.maybeIfStatement() ||
            this.maybeSwitchStatement();
    }

    // if-statement ::=
    //     "if" "(" expression ")" statement
    //     "if" "(" expression ")" statement "else" statement
    maybeIfStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "if"
        const identifier = this.maybeIdentifier("if");
        if (!identifier) {
            return this.popState();
        }

        // "(" expression ")"
        const condition = this.maybeParenthesisExpression();
        if (!condition) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        const {pos} = this;

        // "else"
        const elsekw = this.maybeIdentifier("else");
        if (!elsekw) {
            this.pos = pos;

            return this.popState(new IfStatement({
                identifier, // "if"
                condition, // "(" expression ")"
                statement // statement
            }, {
                start,
                end: this.pos
            }));
        }

        // statement
        const alternative = this.maybeStatement();
        if (!alternative) {
            this.pos = pos;

            return this.popState(new IfStatement({
                identifier, // "if"
                condition, // "(" expression ")"
                statement // statement
            }, {
                start,
                end: this.pos
            }));
        }

        return this.popState(new IfStatement({
            identifier, // "if"
            condition, // "(" expression ")"
            statement, // statement
            elsekw, // "else"
            alternative // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // switch-statement ::=
    //     "switch" "(" expression ")" statement
    maybeSwitchStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "switch"
        const identifier = this.maybeIdentifier("switch");
        if (!identifier) {
            return this.popState();
        }

        // "(" expression ")"
        const expression = this.maybeParenthesisExpression();
        if (!expression) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new SwitchStatement({
            identifier, // "switch"
            expression, // "(" expression ")"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // iteration-statement ::=
    //     "while" "(" expression ")" statement
    //     "do" statement "while" "(" expression ")" ";"
    //     "for" "(" expression? ";" expression? ";" expression? ")" statement
    //     "for" "(" declaration expression? ";" expression? ")" statement
    maybeIterationStatement() {
        return this.maybeWhileStatement() ||
            this.maybeDoWhileStatement() ||
            this.maybeForStatement();
    }

    // while-statement ::=
    //     "while" "(" expression ")" statement
    maybeWhileStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "while"
        const identifier = this.maybeIdentifier("while");
        if (!identifier) {
            return this.popState();
        }

        // "(" expression ")"
        const condition = this.maybeParenthesisExpression();
        if (!condition) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new WhileStatement({
            identifier, // "while"
            condition, // "(" expression ")"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // do-while-statement ::=
    //     "do" statement "while" "(" expression ")" ";"
    maybeDoWhileStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "do"
        const dokw = this.maybeIdentifier("do");
        if (!dokw) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        // "while"
        const identifier = this.maybeIdentifier("while");
        if (!identifier) {
            return this.popState();
        }

        // "(" expression ")"
        const condition = this.maybeParenthesisExpression();
        if (!condition) {
            return this.popState();
        }

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new DoWhileStatement({
            dokw, // "do"
            statement, // statement
            identifier, // "while"
            condition, // "(" expression ")"
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // for-statement ::=
    //     "for" "(" expression? ";" expression? ";" expression? ")" statement
    //     "for" "(" declaration expression? ";" expression? ")" statement
    maybeForStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "for"
        const identifier = this.maybeIdentifier("for");
        if (!identifier) {
            return this.popState();
        }

        // "("
        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        // expression?
        // declaration-specifiers init-declarator-list?
        const initialization = this.maybeDeclaration(false) || this.maybeExpression();

        // ";"
        const initsemi = this._maybeTokenExpression(";");
        if (!initsemi) {
            return this.popState();
        }

        // expression?
        const condition = this.maybeExpression();

        // ";"
        const condsemi = this._maybeTokenExpression(";");
        if (!condsemi) {
            return this.popState();
        }

        // expression?
        const afterthought = this.maybeExpression();

        // ")"
        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        // statement
        const statement = this.maybeStatement();
        if (!statement) {
            return this.popState();
        }

        return this.popState(new ForStatement({
            identifier, // "for"
            open, // "("
            initialization, // expression? || declaration-specifiers init-declarator-list?
            initsemi, // ";"
            condition, // expression?
            condsemi, // ";"
            afterthought, // expression?
            close, // ")"
            statement // statement
        }, {
            start,
            end: this.pos
        }));
    }

    // jump-statement ::=
    //     "goto" identifier ";"
    //     "continue" ";"
    //     "break" ";"
    //     "return" expression? ";"
    maybeJumpStatement() {
        return this.maybeGotoStatement() ||
            this.maybeContinueStatement() ||
            this.maybeBreakStatement() ||
            this.maybeReturnStatement();
    }

    // goto-statement ::=
    //     "goto" identifier ";"
    maybeGotoStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "goto"
        const goto = this.maybeIdentifier("goto");
        if (!goto) {
            return this.popState();
        }

        // identifier
        const identifier = this.maybeIdentifier();
        if (!identifier) {
            return this.popState();
        }

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new GotoStatement({
            goto, // "goto"
            identifier, // identifier
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // continue-statement ::=
    //     "continue" ";"
    maybeContinueStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "continue"
        const keyword = this.maybeIdentifier("continue");
        if (!keyword) {
            return this.popState();
        }

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new ContinueStatement({
            keyword, // "continue"
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // break-statement ::=
    //     "break" ";"
    maybeBreakStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "break"
        const keyword = this.maybeIdentifier("break");
        if (!keyword) {
            return this.popState();
        }

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new BreakStatement({
            keyword, // "break"
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    // return-statement ::=
    //     "return" expression? ";"
    maybeReturnStatement() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        // "return"
        const keyword = this.maybeIdentifier("return");
        if (!keyword) {
            return this.popState();
        }

        // expression?
        const expression = this.maybeExpression();

        // ";"
        const semicolon = this._maybeTokenExpression(";");
        if (!semicolon) {
            return this.popState();
        }

        return this.popState(new ReturnStatement({
            keyword, // "return"
            expression, // expression?
            semicolon // ";"
        }, {
            start,
            end: this.pos
        }));
    }

    pushNextPos() {
        this.pushState();
        this.consumeCommentOrSpace();
        return this.pos < this.len;
    }

    nextToken() {
        this.consumeCommentOrSpace();
        if (this.pos >= this.len) {
            return false;
        }

        return this.input[this.pos++];
    }

    maybeIdentifier(name = undefined) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const words = [];

        while (this.pos < this.len) {
            noWordReg.lastIndex = this.pos;
            const match = noWordReg.exec(this.input);
            if (match === null || this.pos === match.index) {
                break;
            }

            const word = this.input.slice(this.pos, match.index);
            if (name && name !== word) {
                break;
            }

            words.push(word);
            this.pos = match.index;

            if (this.input.slice(this.pos, this.pos + 2) !== "::") {
                break;
            }

            words.push("::");
            this.pos += "::".length;
        }

        if (words.at(-1) === "::") {
            words.pop();
            this.pos -= "::".length;
        }

        if (words.length === 0) {
            return this.popState();
        }

        const identifier = words.join("");

        return this.popState(new Identifier(identifier, {
            start: this.pos - identifier.length,
            end: this.pos
        }));
    }

    maybeConstant() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        let sign = this.input[this.pos];
        if (sign === "+" || sign === "-") {
            this.pos++;
            this.consumeCommentOrSpace();
            if (this.pos >= this.len) {
                return this.popState();
            }
        } else {
            sign = "";
        }

        floatingPointConstantReg.lastIndex = 0;
        const floatingPointConstantMatch = floatingPointConstantReg.exec(this.input.slice(this.pos));
        if (floatingPointConstantMatch !== null) {
            this.pos += floatingPointConstantMatch[0].length;
            const value = this.input.slice(start, this.pos);
            return this.popState(new Constant({
                sign,
                value
            }, {
                start,
                end: this.pos
            }));
        }

        integerConstantReg.lastIndex = 0;
        const integerConstantMatch = integerConstantReg.exec(this.input.slice(this.pos));
        if (integerConstantMatch !== null) {
            this.pos += integerConstantMatch[0].length;
            const value = this.input.slice(start, this.pos);
            return this.popState(new Constant({
                sign,
                value
            }, {
                start,
                end: this.pos
            }));
        }

        characterConstantReg.lastIndex = 0;
        const characterConstantMatch = characterConstantReg.exec(this.input.slice(this.pos));
        if (characterConstantMatch !== null) {
            this.pos += characterConstantMatch[0].length;
            const value = this.input.slice(start, this.pos);
            return this.popState(new Constant({
                sign,
                value
            }, {
                start,
                end: this.pos
            }));
        }

        return this.popState();
    }

    _maybeStringLiteral() {
        this.consumeCommentOrSpace();
        if (this.pos >= this.len) {
            return false;
        }
        const start = this.pos;

        stringLiteralConstantReg.lastIndex = 0;
        const stringLiteralConstantMatch = stringLiteralConstantReg.exec(this.input.slice(this.pos));
        if (stringLiteralConstantMatch !== null) {
            this.pos += stringLiteralConstantMatch[0].length;
            const literal = this.input.slice(start, this.pos).replace(/\\\n/g, "");
            return new StringLiteral(literal, {
                start,
                end: this.pos
            });
        }

        return false;
    }

    maybeStringLiteral() {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const literals = this._maybeExpressionList("_maybeStringLiteral");

        if (literals.length === 0) {
            return this.popState();
        }

        if (literals.length === 1) {
            return this.popState(literals[0]);
        }

        return this.popState(new StringLiteralList(literals, {
            start,
            end: this.pos
        }));
    }

    maybePreprocessedLine() {
        preprocessedLineReg.lastIndex = 0;
        const preprocessedLinetMatch = preprocessedLineReg.exec(this.input.slice(this.pos));
        if (preprocessedLinetMatch !== null) {
            this.pos += preprocessedLinetMatch[0].length;
            return true;
        }
        return false;
    }

    maybePragma() {
        pragmaReg.lastIndex = 0;
        const pragmatMatch = pragmaReg.exec(this.input.slice(this.pos));
        if (pragmatMatch !== null) {
            this.pos += pragmatMatch[0].length;
            return true;
        }
        return false;
    }

    consumeCommentOrSpace() {
        if (this.pos >= this.len) {
            return false;
        }

        const {pos} = this;

        while (this.maybeComment() || this.maybeSpace() || this.maybePreprocessedLine() || this.maybePragma()) {
            if (this.pos === this.len) {
                break;
            }
        }

        this.lastIndex = Math.max(this.lastIndex, this.pos);

        return this.pos !== pos;
    }

    maybeSpace() {
        if (this.pos >= this.len) {
            return false;
        }

        noSpaceReg.lastIndex = this.pos;
        const match = noSpaceReg.exec(this.input);
        if (match === null) {
            this.pos = this.len;
            return true;
        }

        if (this.pos === match.index) {
            return false;
        }

        this.pos = match.index;
        return true;
    }

    maybeComment() {
        if (this.pos >= this.len) {
            return false;
        }

        const {pos} = this;

        if (this.input.startsWith("//", this.pos)) {
            this.pos = this.input.indexOf("\n", this.pos + "//".length);
            if (this.pos === -1) {
                this.pos = this.len;
            }
            this.pos += "\n".length;

            this.comments.set(pos, new LineComment({
                start: pos,
                endt: this.pos,
            }));
            return true;
        }

        this.pushState();

        if (this.input.startsWith("/*", this.pos)) {
            this.pos = this.input.indexOf("*/", this.pos + "/*".length);
            if (this.pos === -1) {
                this.popState();
                return false;
            }
            this.popState(true);

            this.pos += "*/".length;

            this.comments.set(pos, new BlockComment({
                start: pos,
                end: this.pos
            }));
            return true;
        }

        return this.popState();
    }

    pushState() {
        this.states.push(this.pos);
    }

    popState(doNotRestore = false) {
        // if (this.states.length === 0) {
        //     debugger;
        // }
        if (doNotRestore) {
            this.states.pop();
        } else {
            this.pos = this.states.pop();
        }
        return doNotRestore;
    }

    _maybeTokenExpression(token) {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        if (!this.input.startsWith(token, this.pos)) {
            return this.popState();
        }

        this.pos += token.length;

        return this.popState(new Expression(token, {
            start: this.pos - token.length,
            end: this.pos
        }));
    }

    _maybeExpressionList(maybeExpressionList, separator = "") {
        this.consumeCommentOrSpace();

        if (!Array.isArray(maybeExpressionList)) {
            maybeExpressionList = [maybeExpressionList];
        }

        const expressions = [];
        let {
            pos
        } = this;
        let expression;
        // eslint-disable-next-line no-cond-assign
        while (expression = (() => {
                for (const maybe of maybeExpressionList) {
                    const expr = this[maybe]();
                    if (expr) {
                        return expr;
                    }
                }
                return false;
            })()) {
            expressions.push(expression);
            pos = this.pos;

            if (separator) {
                this.consumeCommentOrSpace();
                if (!this.input.startsWith(separator, this.pos)) {
                    break;
                }
                this.pos += separator.length;
            }

            this.consumeCommentOrSpace();
        }
        this.pos = pos;
        return expressions;
    }

    _maybeDeclaratorExpression(maybeDeclarator) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        const open = this._maybeTokenExpression("(");
        if (!open) {
            return this.popState();
        }

        const declarator = this[maybeDeclarator]();
        if (!declarator) {
            return this.popState();
        }

        const close = this._maybeTokenExpression(")");
        if (!close) {
            return this.popState();
        }

        return this.popState(new DeclaratorExpression({
            open,
            declarator,
            close
        }, {
            start,
            end: this.pos
        }));
    }

    _maybeOperatorExpression(op = "") {
        if (!this.pushNextPos()) {
            return this.popState();
        }

        const operators = [
            "!=",
            "%",
            "%=",
            "&",
            "&&",
            "&=",
            "*",
            "*=",
            "+",
            "+=",
            "-",
            "-=",
            "/",
            "/=",
            "<",
            "<<",
            "<<=",
            "<=",
            "=",
            "==",
            ">",
            ">=",
            ">>",
            ">>=",
            "^",
            "^=",
            "|",
            "|=",
            "||",
        ].sort(({length: a}, {length: b}) => b - a);

        for (const operator of operators) {
            if (this.input.startsWith(operator, this.pos)) {
                if (op && op !== operator) {
                    return this.popState();
                }

                this.pos += operator.length;
                return this.popState(new OperatorExpression(operator, {
                    start: this.pos - operator.length,
                    end: this.pos
                }));
            }
        }

        return this.popState();
    }

    _maybeLogicalExpression(operators, maybeLogicalExpression) {
        if (!this.pushNextPos()) {
            return this.popState();
        }
        const start = this.pos;

        operators.sort((a, b) => b.length - a.length);

        const expressions = [];
        let pos = this.pos;
        let expression;
        while (expression = this[maybeLogicalExpression]()) { // eslint-disable-line no-cond-assign
            expressions.push(expression);

            this.consumeCommentOrSpace();
            pos = this.pos;
            if (this.pos >= this.length) {
                break;
            }

            let found = false;
            for (const op of operators) {
                const operator = this._maybeOperatorExpression(op);
                if (operator) {
                    expressions.push(operator);
                    found = true;
                    break;
                }
            }

            if (!found) {
                // no operators where found
                break;
            }
        }
        this.pos = pos;

        if (expressions.length === 0) {
            return this.popState();
        }

        // remove last added operation
        if (expressions.at(-1) instanceof OperatorExpression) {
            const operator = expressions.pop();
            this.pos = operator.loc.start;
        }

        if (expressions.length === 1) {
            return this.popState(expressions[0]);
        }

        return this.popState(new LogicalExpression(expressions, {
            start,
            end: this.pos
        }));
    }
}

exports.Parser = Parser;
