#!/usr/bin/env node

const fs = require("node:fs");
const sysPath = require("node:path");

const typedefs = require("../generator/c_parser/typedefs");
const {Parser} = require("../generator/c_parser/Parser");

const {ArrayExpression} = require("../generator/c_parser/symbols/ArrayExpression");
const {ArrowExpression} = require("../generator/c_parser/symbols/ArrowExpression");
const {AssignmentExpression} = require("../generator/c_parser/symbols/AssignmentExpression");
const {BlockComment} = require("../generator/c_parser/symbols/BlockComment");
const {BreakStatement} = require("../generator/c_parser/symbols/BreakStatement");
const {CaseLabeledStatement} = require("../generator/c_parser/symbols/CaseLabeledStatement");
const {CompoundStatement} = require("../generator/c_parser/symbols/CompoundStatement");
const {Declaration} = require("../generator/c_parser/symbols/Declaration");
const {DeclaratorExpression} = require("../generator/c_parser/symbols/DeclaratorExpression");
const {Declarator} = require("../generator/c_parser/symbols/Declarator");
const {DefaultLabeledStatement} = require("../generator/c_parser/symbols/DefaultLabeledStatement");
const {DoWhileStatement} = require("../generator/c_parser/symbols/DoWhileStatement");
const {ExpressionStatement} = require("../generator/c_parser/symbols/ExpressionStatement");
const {ForStatement} = require("../generator/c_parser/symbols/ForStatement");
const {IdentifierDesignator} = require("../generator/c_parser/symbols/IdentifierDesignator");
const {IdentifierListExpression} = require("../generator/c_parser/symbols/IdentifierListExpression");
const {Identifier} = require("../generator/c_parser/symbols/Identifier");
const {IfStatement} = require("../generator/c_parser/symbols/IfStatement");
const {InitDeclarator} = require("../generator/c_parser/symbols/InitDeclarator");
const {LineComment} = require("../generator/c_parser/symbols/LineComment");
const {LogicalExpression} = require("../generator/c_parser/symbols/LogicalExpression");
const {OperatorExpression} = require("../generator/c_parser/symbols/OperatorExpression");
const {ParameterTypeListExpression} = require("../generator/c_parser/symbols/ParameterTypeListExpression");
const {PostfixExpression} = require("../generator/c_parser/symbols/PostfixExpression");
const {ReturnStatement} = require("../generator/c_parser/symbols/ReturnStatement");
const {StructOrUnionSpecifier} = require("../generator/c_parser/symbols/StructOrUnionSpecifier");
const {SwitchStatement} = require("../generator/c_parser/symbols/SwitchStatement");
const {UnaryExpression} = require("../generator/c_parser/symbols/UnaryExpression");
const {VariadicParameter} = require("../generator/c_parser/symbols/VariadicParameter");
const {WhileStatement} = require("../generator/c_parser/symbols/WhileStatement");

let libname;

const getReplacedInput = (input, replacements, rstart, rend, all = rstart === 0 && rend === input.length) => {
    replacements = replacements.filter(({start, end}) => {
        if (start === end && !all) {
            return rstart < start && end < rend;
        }
        return rstart <= start && end <= rend;
    });

    replacements.sort(({
        start: astart,
        end: aend,
        replace: areplace,
    }, {
        start: bstart,
        end: bend,
        replace: breplace,
    }) => {
        if (astart !== bstart) {
            return astart - bstart;
        }

        if (astart === aend) {
            // zero length replacement should be done first
            if (bstart !== bend) {
                return -1;
            }

            if (aend === bend) {
                // between 2 zero length replacements, function wrapping should be done first
                if (areplace.startsWith("(function()")) {
                    return -1;
                }

                if (breplace.startsWith("(function()")) {
                    return 1;
                }

                // between 2 zero length replacements, function ending should be done last
                if (areplace.endsWith(" end)()")) {
                    return 1;
                }

                if (breplace.endsWith(" end)()")) {
                    return -1;
                }
            }

            return bend - aend;
        }

        if (bstart === bend) {
            return 1;
        }

        return bend - aend;
    });

    for (let i = replacements.length - 1; i > 0; i--) {
        const {start: istart, end: iend} = replacements[i];
        const {start: jstart, end: jend} = replacements[i - 1];

        if (jstart <= istart && iend <= jend && istart < jend) {
            if (jstart === istart && iend === jend) {
                replacements[i - 1] = replacements[i];
            }

            replacements.splice(i, 1);

            if (i < replacements.length) {
                i++;
            }
        }
    }

    const converted = [];
    let lastIndex = rstart;

    for (const {start, end, replace} of replacements) {
        if (lastIndex !== start) {
            converted.push(input.slice(lastIndex, start));
        }

        converted.push(replace);
        lastIndex = end;
    }

    if (lastIndex !== rend) {
        converted.push(input.slice(lastIndex, rend));
    }

    return converted.join("");
};

const getIdentifierName = (input, replacements, identifier) => {
    const {start, end} = identifier.loc;
    return getReplacedInput(input, replacements, start, end);
};

const PRIMITIVE_TYPES = new Set([
    "char",
    "short",
    "int",
    "long",
    "float",
    "double",
    "signed",
    "unsigned",

    // https://en.cppreference.com/w/cpp/language/types
    "signed char",
    "unsigned char",
    "short int",
    "signed short",
    "signed short int",
    "unsigned short",
    "unsigned short int",
    "signed int",
    "unsigned int",
    "long int",
    "signed long",
    "signed long int",
    "unsigned long",
    "unsigned long int",
    "long long",
    "long long int",
    "signed long long",
    "signed long long int",
    "unsigned long long",
    "unsigned long long int",
    "long double"
]);

const NUMBER_TYPES = new Set([
    ...PRIMITIVE_TYPES,
    "size_t",
]);

const BIT_OPERATIONS_MAP = new Map([
    ["|", "bor"],
    ["^", "bxor"],
    ["&", "band"],
    ["~", "bnot"],
    ["<<", "lshift"],
    [">>", "arshift"],
]);

const startInBlockCommentReg = /^[^\S\r\n]+\*/mg;

const getNodeIndent = (input, node) => {
    let lstart = node.loc.start;
    while (lstart > 0 && input[lstart - 1] !== "\n") {
        lstart--;
    }

    return " ".repeat(node.loc.start - lstart);
};

const setLastReplacementIndent = (input, node, replacements) => {
    const LF = "\n";
    const replacement = replacements.at(-1);
    replacement.replace = LF + getNodeIndent(input, node) + replacement.replace;
};

const addCommentsReplacement = (input, comments, replacements) => {
    for (const [, comment] of comments.entries()) {
        const {start, end} = comment;
        if (comment instanceof BlockComment) {
            const bstart = start + "/*".length;
            const bend = end - "*/".length;

            replacements.push({
                start,
                end: bstart,
                replace: "--[["
            });

            startInBlockCommentReg.lastIndex = 0;
            let match;
            // eslint-disable-next-line no-cond-assign
            while (match = startInBlockCommentReg.exec(getReplacedInput(input, replacements, bstart, bend))) {
                const rstart = bstart + match.index + match[0].length - 1;

                replacements.push({
                    start: rstart,
                    end: rstart + 1,
                    replace: "-"
                });
            }

            replacements.push({
                start: bend,
                end,
                replace: "--]]"
            });
        } else if (comment instanceof LineComment) {
            replacements.push({
                start,
                end: start + "//".length,
                replace: "--"
            });
        }
    }
};

const addOperatorReplacement = (input, operator, replace, replacements, spaces = true) => {
    const {start, end} = operator.loc;

    const replacement = [];

    if (spaces && start > 0 && /\b/.test(input[start - 1])) {
        replacement.push(" ");
    }

    replacement.push(replace);

    if (spaces && end < input.length && /\b/.test(input[end])) {
        replacement.push(" ");
    }

    replacements.push({
        start,
        end,
        replace: replacement.join(""),
    });
};

const addStatementReplacement = (input, statement, replace, replacements) => {
    if (statement.open && statement.close) {
        let start = statement.open.loc.start;

        if (!replace) {
            while (start > 0 && /^\s/.test(input[start - 1])) {
                start--;
            }
        }

        replacements.push({
            start,
            end: statement.open.loc.end,
            replace
        }, {
            start: statement.close.loc.start,
            end: statement.close.loc.end,
            replace: "end"
        });
    } else {
        if (replace) {
            let start = statement.loc.start;
            while (start > 0 && /^\s/.test(input[start - 1])) {
                start--;
            }

            replacements.push({
                start,
                end: start,
                replace: ` ${ replace }`
            });
        }

        replacements.push({
            start: statement.loc.end,
            end: statement.loc.end,
            replace: "end"
        });
    }
};

const addDeclaratorReplacement = (input, node, declarator, replacements) => {
    // do not change static declaration to tell the developper that a special care is needed
    if (node instanceof Declaration && node.specifiers.some(specifier => specifier instanceof Identifier && specifier.name === "static")) {
        return;
    }

    while (declarator instanceof DeclaratorExpression) {
        declarator = declarator.declarator;
    }

    if (declarator instanceof Identifier) {
        const identifier = declarator;

        replacements.push({
            start: node.loc.start,
            end: identifier.loc.end,
            replace: `local ${ getIdentifierName(input, replacements, identifier) }`
        });
    } else if (
        declarator instanceof Declarator
        && declarator.declarators.length !== 0
        && declarator.declarators[0] instanceof Identifier
        && declarator.declarators.slice(1).every(decl => decl instanceof ArrayExpression)
    ) {
        const identifier = declarator.declarators[0];

        replacements.push({
            start: node.loc.start,
            end: declarator.declarators.at(-1).loc.end,
            replace: `local ${ getIdentifierName(input, replacements, identifier) }`
        });
    } else {
        throw new Error("There is something wrong");
    }
};

const addBitOperationReplacement = (input, op, operator, lhs, rhs, replacements) => {
    addOperatorReplacement(input, operator, ",", replacements, false);

    replacements.push({
        start: lhs.loc.start,
        end: rhs.loc.end,
        replace: `bit.${ op }(${ getReplacedInput(input, replacements, lhs.loc.start, rhs.loc.end) })`
    });
};

const replacers = {};

replacers.ArrowExpression = (parser, replacements, node, parents) => {
    const {arrow} = node;

    replacements.push({
        start: arrow.loc.start,
        end: arrow.loc.end,
        replace: "."
    });
};

replacers.AssignmentExpression = (parser, replacements, node, parents) => {
    const {input} = parser;

    const {
        unary,
        operator,
        expression
    } = node;

    const op = operator.operator.slice(0, -1);

    if ([
        "*=",
        "/=",
        "%=",
        "+=",
        "-=",
    ].includes(operator.operator)) {
        replacements.push({
            start: operator.loc.start,
            end: operator.loc.end,
            replace: `= ${ getReplacedInput(input, replacements, unary.loc.start, unary.loc.end) } ${ op }`
        });

        replacements.push({
            start: expression.loc.start,
            end: expression.loc.start,
            replace: "("
        });

        replacements.push({
            start: expression.loc.end,
            end: expression.loc.end,
            replace: ")"
        });
    } else if (BIT_OPERATIONS_MAP.has(op) && operator.operator.at(-1) === "=") {
        replacements.push({
            start: operator.loc.start,
            end: operator.loc.end,
            replace: "="
        });

        const replace = `bit.${ BIT_OPERATIONS_MAP.get(op) }(${ getReplacedInput(input, replacements, unary.loc.start, unary.loc.end) }, ${ getReplacedInput(input, replacements, expression.loc.start, expression.loc.end, true) })`;

        for (let i = replacements.length - 1; i >= 0; i--) {
            const {start, end} = replacements[i];
            if (expression.loc.start <= start && end <= expression.loc.end) {
                replacements.splice(i, 1);
            }
        }

        replacements.push({
            start: expression.loc.start,
            end: expression.loc.end,
            replace
        });
    }

    // multi assign
    if (parents.at(-1) instanceof AssignmentExpression || parents.at(-1) instanceof InitDeclarator) {
        let top = parents.length - 1;
        while (top >= 0 && !(parents[top] instanceof Declaration || parents[top] instanceof ExpressionStatement)) {
            top--;
        }

        replacements.push({
            start: parents[top].loc.start,
            end: parents[top].loc.start,
            replace: `${ getReplacedInput(input, replacements, node.loc.start, node.loc.end) }; `
        });

        replacements.push({
            start: node.loc.start,
            end: node.loc.end,
            replace: `${ getReplacedInput(input, replacements, unary.loc.start, unary.loc.end).trim() }`
        });
    }
};

const wrapCompoundStatement = (replacements, node) => {
    const {open, close} = node;

    replacements.push({
        start: open.loc.start,
        end: open.loc.end,
        replace: ";(function() "
    });

    replacements.push({
        start: close.loc.start,
        end: close.loc.end,
        replace: " end)()"
    });
};

replacers.CompoundStatement = (parser, replacements, node, parents) => {
    if (parents.at(-1) instanceof CompoundStatement) {
        wrapCompoundStatement(replacements, node);
    }
};

replacers.ConditionalExpression = (parser, replacements, node, parents) => {
    const {input} = parser;

    const {
        condition,
        ternary,
        // truthy,
        colon,
        falsy
    } = node;

    replacements.push({
        start: condition.loc.start,
        end: condition.loc.start,
        replace: "(function() if "
    });

    const treplace = [];

    if (!/\s/.test(input[ternary.loc.start - 1])) {
        treplace.push(" ");
    }

    treplace.push("then return");

    if (!/\s/.test(input[ternary.loc.end + 1])) {
        treplace.push(" ");
    }

    replacements.push({
        start: ternary.loc.start,
        end: ternary.loc.end,
        replace: treplace.join("")
    });

    const creplace = [];

    if (!/\s/.test(input[colon.loc.start - 1])) {
        creplace.push(" ");
    }

    creplace.push("else return");

    if (!/\s/.test(input[colon.loc.end + 1])) {
        creplace.push(" ");
    }

    replacements.push({
        start: colon.loc.start,
        end: colon.loc.end,
        replace: creplace.join("")
    });

    replacements.push({
        start: falsy.loc.end,
        end: falsy.loc.end,
        replace: " end end)()"
    });
};

// https://learn.microsoft.com/en-us/cpp/c-language/c-floating-point-constants?view=msvc-170
const floatingSuffix = "[flFL]";

// https://learn.microsoft.com/en-us/cpp/c-language/c-integer-constants?view=msvc-170
const integerSuffix = (() => {
    const unsignedSuffix = "[uU]";
    const longSuffix = "[lL]";
    const longLongSuffix = "(?:ll|LL)";
    const _64BitIntegerSuffix = "[iI]64";

    return `(?:${ [
        `${ unsignedSuffix }${ _64BitIntegerSuffix }`,
        `${ unsignedSuffix }${ longLongSuffix }`,
        `${ unsignedSuffix }${ longSuffix }?`,
        `${ longLongSuffix }${ unsignedSuffix }?`,
        `${ longSuffix }${ unsignedSuffix }?`,
        `${ _64BitIntegerSuffix }`,
    ].join("|") })`;
})();

const hexadecimalPrefix = /^0[xX]/;

const integerConstantSuffix = new RegExp(`${ integerSuffix }$`);
const numberConstantSuffix = new RegExp(`${ [floatingSuffix, integerSuffix].join("|") }$`);

replacers.Constant = (parser, replacements, node, parents) => {
    const {sign, value} = node;
    const {start, end} = node.loc;
    if (value.startsWith("L'")) {
        replacements.push({
            start,
            end,
            replace: `${ sign }string.byte(${ value.slice(1) })`
        });
    } else if (value.startsWith("'")) {
        replacements.push({
            start,
            end,
            replace: `${ sign }string.byte(${ value })`
        });
    } else if (numberConstantSuffix.test(value)) {
        replacements.push({
            start,
            end,
            replace: `${ sign }${ value.replace(hexadecimalPrefix.test(value) ? integerConstantSuffix : numberConstantSuffix, "") }`
        });
    }
};

const getDefaultValue = typename => {
    if (typename.name === "bool" || typename.name === "_Bool") {
        return "false";
    }

    if (NUMBER_TYPES.has(typename.name)) {
        return "0";
    }

    return `${ typename.name.replace(/^(?=al_|AL)/, `${ libname }.`) }()`;
};

const getTypeName = specifiers => {
    let i = 0;

    if (specifiers[i].name === "extern") {
        i++;
    }

    if (specifiers[i].name === "static") {
        i++;
    }

    if (specifiers[i].name === "volatile") {
        i++;
    }

    return specifiers[i];
}

replacers.Declaration = (parser, replacements, node, parents) => {
    const {input} = parser;

    if (node.declarators.length !== 0 && !(node.specifiers.at(-1) instanceof StructOrUnionSpecifier) && node.declarators.every(decl =>
            decl instanceof Identifier ||
            decl instanceof InitDeclarator && decl.declarator instanceof Identifier ||
            decl instanceof Declarator && decl.declarators.length === 1 && decl.declarators[0] instanceof Identifier
        )) {
        const typename = getTypeName(node.specifiers);
        const defval = getDefaultValue(typename);

        const declarators = node.declarators.map(decl => {
            const identifier = decl instanceof Identifier ? decl : decl instanceof InitDeclarator ? decl.declarator : decl.declarators[0];
            return getIdentifierName(input, replacements, identifier);
        }).join(", ");

        const intializers = node.declarators.map(decl => {
            if (decl instanceof Identifier) {
                return defval;
            }

            if (decl instanceof InitDeclarator) {
                const {initializer: {loc: {start, end}}} = decl;
                return getReplacedInput(input, replacements, start, end, true);
            }

            return "nil";
        }).join(", ");

        const decl = node.declarators[0];
        const start = decl instanceof Identifier ? decl.loc.start : decl instanceof InitDeclarator ? decl.declarator.loc.start : decl.declarators[0].loc.start;

        // separate replacement to not be in conflict with ForStatement replacement
        replacements.push({
            start: node.loc.start,
            end: start,
            replace: "local "
        });

        replacements.push({
            start,
            end: node.loc.end,
            replace: intializers !== "nil" ? `${ declarators } = ${ intializers }` : declarators
        });
        return;
    }

    if (node.declarators.length === 1) {
        if (node.declarators[0] instanceof InitDeclarator) {
            const [{declarator}] = node.declarators;
            addDeclaratorReplacement(input, node, declarator, replacements);
        } else if (node.declarators[0] instanceof Declarator) {
            const top = node.declarators[0];
            if (top.pointers.length !== 0 && top.declarators.length === 1) {
                const [declarator] = top.declarators;
                addDeclaratorReplacement(input, node, declarator, replacements);
            }
        } else if (node.declarators[0] instanceof Identifier && node.specifiers.length === 1 && node.specifiers[0] instanceof Identifier) {
            const identifier = node.declarators[0];
            const typename = node.specifiers[0];

            replacements.push({
                start: node.loc.start,
                end: node.loc.end,
                replace: `local ${ getIdentifierName(input, replacements, identifier) }= ${ getDefaultValue(typename) }`
            });
        }
    }
};

replacers.DoWhileStatement = (parser, replacements, node, parents) => {
    const {
        dokw,
        statement,
        identifier,
        condition
    } = node;

    replacements.push({
        start: dokw.loc.start,
        end: dokw.loc.end,
        replace: "repeat"
    });

    if (statement.open && statement.close) {
        replacements.push({
            start: statement.open.loc.start,
            end: statement.open.loc.end,
            replace: " "
        }, {
            start: statement.close.loc.start,
            end: statement.close.loc.end,
            replace: " "
        });
    }

    replacements.push({
        start: identifier.loc.start,
        end: identifier.loc.end,
        replace: "until"
    });

    replacements.push({
        start: condition.loc.start,
        end: condition.loc.start,
        replace: "not "
    });
};

replacers.Expression = (parser, replacements, node, parents) => {
    const {input} = parser;

    let i = parents.length;
    for (; i >= 0; i--) {
        const parent = parents[i];
        if (parent instanceof ForStatement || parent instanceof CompoundStatement) {
            break;
        }
    }

    if (i !== -1 && parents[i] instanceof CompoundStatement) {
        i = -1;
    }

    if (node.expression === ";" && i === -1) {
        const {start, end} = node.loc;
        const pos = input.indexOf("\n", end);
        if (pos === -1 || pos === end || input.slice(end, pos).trim().length === 0) {
            replacements.push({
                start,
                end,
                replace: ""
            });
        }
    }
};

const addSimpleForStatementReplacement = (parser, replacements, node, unary) => {
    const {input} = parser;

    const {
        open,
        initsemi,
        condition,
        afterthought,
        close,
    } = node;

    if (!(condition instanceof LogicalExpression)) {
        return;
    }

    const name = unary.name;

    const {expressions} = condition;
    if (!(
            expressions.length === 3 &&
            expressions[0] instanceof Identifier &&
            expressions[0].name === name &&
            expressions[1] instanceof OperatorExpression &&
            ["<", "<=", ">", ">="].includes(expressions[1].operator)
        )) {
        return;
    }

    if (
        afterthought instanceof PostfixExpression &&
        afterthought.primary instanceof Identifier &&
        afterthought.primary.name === name &&
        afterthought.accessors.length === 1 &&
        afterthought.accessors[0] instanceof OperatorExpression &&
        ["++", "--"].includes(afterthought.accessors[0].operator)

        ||
        afterthought instanceof UnaryExpression &&
        afterthought.expression instanceof Identifier &&
        afterthought.expression.name === name &&
        afterthought.operator instanceof OperatorExpression &&
        ["++", "--"].includes(afterthought.operator.operator)

        ||
        afterthought instanceof AssignmentExpression &&
        afterthought.unary instanceof Identifier &&
        afterthought.unary.name === name &&
        afterthought.operator instanceof OperatorExpression &&
        ["+=", "-="].includes(afterthought.operator.operator)
    ) {
        replacements.push({
            start: open.loc.start,
            end: unary.loc.start,
            replace: /\w/.test(input[open.loc.start - 1]) ? " " : ""
        });

        replacements.push({
            start: initsemi.loc.start,
            end: initsemi.loc.end,
            replace: ","
        });

        replacements.push({
            start: condition.loc.start,
            end: expressions[2].loc.start,
            replace: /\w/.test(input[expressions[2].loc.start + 1]) ? " " : ""
        });

        let step = afterthought instanceof AssignmentExpression ? getReplacedInput(input, replacements, afterthought.expression.loc.start, afterthought.expression.loc.end) : "1";

        if (
            afterthought instanceof PostfixExpression && afterthought.accessors[0].operator === "--" ||
            afterthought instanceof UnaryExpression && afterthought.operator.operator === "--" ||
            afterthought instanceof AssignmentExpression && afterthought.operator.operator === "-="
        ) {
            step = `-${ step }`;
        }

        let replace = "";

        if (["<", ">"].includes(expressions[1].operator)) {
            replace = " - INDEX_BASE";
            if (step !== "1") {
                // start + (math.floor((end - start + 1) / step) - 1) * step
                replace += ` * ${ step }`;
            }
        }

        if (step !== "1") {
            replace += `, ${ step }`;
        }

        replacements.push({
            start: expressions[2].loc.end,
            end: close.loc.end,
            replace
        });
    }
};

const replaceSimpleForStatement = (parser, replacements, node, parents) => {
    const {
        initialization,
        condition,
        afterthought,
    } = node;

    if (initialization instanceof AssignmentExpression) {
        const {
            unary,
            operator
        } = initialization;
        if (!(
                unary instanceof Identifier &&
                operator instanceof OperatorExpression &&
                operator.operator === "="
            )) {
            return;
        }
        addSimpleForStatementReplacement(parser, replacements, node, unary);
    } else if (
        initialization instanceof Declaration &&
        initialization.declarators.length === 1 &&
        initialization.declarators[0] instanceof InitDeclarator &&
        initialization.declarators[0].declarator instanceof Identifier
    ) {
        const unary = initialization.declarators[0].declarator;
        addSimpleForStatementReplacement(parser, replacements, node, unary);
    } else if (!initialization && !condition && !afterthought) {
        const {
            identifier,
            open,
            close
        } = node;

        replacements.push({
            start: identifier.loc.start,
            end: identifier.loc.end,
            replace: "while"
        });

        replacements.push({
            start: open.loc.start,
            end: close.loc.end,
            replace: "true"
        });
    }
};

replacers.ForStatement = (parser, replacements, node, parents) => {
    const {input} = parser;
    replaceSimpleForStatement(parser, replacements, node, parents);

    replacements.push({
        start: node.close.loc.end,
        end: node.close.loc.end,
        replace: " do "
    });

    if (node.statement instanceof ForStatement) {
        replacements.push({
            start: node.loc.end,
            end: node.loc.end,
            replace: " end "
        });
    } else {
        addStatementReplacement(input, node.statement, "", replacements);
    }
};

replacers.FunctionDefinition = (parser, replacements, node, parents) => {
    const {input} = parser;

    if (node.statement) {
        const {/*specifiers, */declarator/*, declarations */, statement} = node;
        if (
            declarator instanceof Declarator
            && declarator.declarators.length === 2
            && declarator.declarators[0] instanceof Identifier
            && (declarator.declarators[1] instanceof ParameterTypeListExpression || declarator.declarators[1] instanceof IdentifierListExpression)
        ) {
            const identifier = declarator.declarators[0];
            const parameters = declarator.declarators[1];
            const {open, close} = statement;

            const args = [];
            const fname = ["function", getIdentifierName(input, replacements, identifier)];

            if (fname[1].includes("::")) {
                fname[1] = fname[1].replaceAll("::", ".");
                args.push("self");
            } else {
                fname.unshift("local");
            }

            replacements.push({
                start: node.loc.start,
                end: identifier.loc.end,
                replace: fname.join(" ")
            });


            if (identifier.name === "main" && (!parameters.params || parameters.params.length === 2)) {
                const argc = !parameters.params ? "argc" : parameters.params[0].declarator.name;
                const argv = !parameters.params ? "argv" : parameters.params[1].declarator.declarators[0].name;

                replacements.push({
                    start: parameters.loc.start,
                    end: parameters.loc.end,
                    replace: `(${ argv })`
                });

                replacements.push({
                    start: open.loc.start,
                    end: open.loc.end,
                    replace: `${ getNodeIndent(input, statement.blocks[0]) }local ${ argc } = #${ argv }\n`
                });

                replacements.push({
                    start: close.loc.start,
                    end: close.loc.end,
                    replace: "end\n\nmain(rawget(_G, \"arg\") or {})"
                });

                if (statement.blocks.at(-1) instanceof ReturnStatement) {
                    const last = statement.blocks.at(-1);
                    const indent = getNodeIndent(input, last);

                    replacements.push({
                        start: last.loc.start,
                        end: last.loc.end,
                        replace: indent + [
                            `if ${ libname }.al_is_system_installed() then`,
                            `${ indent }${ libname }.al_uninstall_system()`,
                            "end"
                        ].join(`\n${ indent }`)
                    });
                }

                return;
            }

            const {params} = parameters;
            if (params && (params.length !== 1 || params[0].declarator)) {
                args.push(...params.map((parameter, i) => {
                    if (parameter instanceof VariadicParameter) {
                        return "...";
                    }

                    let {declarator: decl} = parameter;

                    if (!decl) {
                        return `arg${ i + 1 }`;
                    }

                    if (decl instanceof Declarator
                        && decl.declarators.length === 2
                        && decl.declarators[0] instanceof DeclaratorExpression
                        && decl.declarators[1] instanceof ParameterTypeListExpression
                    ) {
                        decl = decl.declarators[0].declarator;
                    }

                    if (decl instanceof Declarator) {
                        if (decl.declarators.length === 0) {
                            throw new Error("There is something wrong");
                        }
                        decl = decl.declarators[0];
                    }

                    if (decl instanceof Identifier) {
                        return getIdentifierName(input, replacements, decl);
                    }

                    throw new Error("There is something wrong");
                }));
            }

            replacements.push({
                start: parameters.loc.start,
                end: parameters.loc.end,
                replace: `(${ args.join(", ") })`
            });

            replacements.push({
                start: parameters.loc.end,
                end: open.loc.end,
                replace: ""
            }, {
                start: close.loc.start,
                end: close.loc.end,
                replace: "end"
            });
        } else {
            throw new Error("There is something wrong");
        }
    }
};

const LUA_RESERVED_KEYWORDS = new Set([
    "and",
    "elseif",
    "end",
    "in",
    "local",
    "global",
    "nil",
    "not",
    "or",
    "repeat",
    "until",
]);

const LUA_KEYWORDS = new Set([
    ...LUA_RESERVED_KEYWORDS,

    // https://www.lua.org/manual/5.1/index.html#index
    // Lua functions
    "_G",
    "_VERSION",
    // "assert", // assert also exists in c
    "collectgarbage",
    "dofile",
    "error",
    "getfenv",
    "getmetatable",
    "ipairs",
    "load",
    "loadfile",
    "loadstring",
    "module",
    "next",
    "pairs",
    "pcall",
    "print",
    "rawequal",
    "rawget",
    "rawset",
    "require",
    "select",
    "setfenv",
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "unpack",
    "xpcall",

    "coroutine",
    "debug",
    "io",
    "math",
    "os",
    "package",
    "string",
    "table",
]);

replacers.Identifier = (parser, replacements, node, parents) => {
    if (parents.at(-1) instanceof IdentifierDesignator) {
        const {name} = node;
        const {dot, identifier} = parents.at(-1);

        if (LUA_RESERVED_KEYWORDS.has(name)) {
            replacements.push({
                start: dot.loc.start,
                end: dot.loc.end,
                replace: ""
            });
            replacements.push({
                start: identifier.loc.start,
                end: identifier.loc.start,
                replace: "[\""
            });
            replacements.push({
                start: identifier.loc.end,
                end: identifier.loc.end,
                replace: "\"]"
            });
        }
        return;
    }

    if (parents.at(-1) instanceof ArrowExpression) {
        const {arrow, identifier} = parents.at(-1);
        const {name} = identifier;

        if (LUA_RESERVED_KEYWORDS.has(name)) {
            replacements.push({
                start: arrow.loc.start,
                end: arrow.loc.end,
                replace: ""
            });
            replacements.push({
                start: identifier.loc.start,
                end: identifier.loc.start,
                replace: "[\""
            });
            replacements.push({
                start: identifier.loc.end,
                end: identifier.loc.end,
                replace: "\"]"
            });
        }
        return;
    }

    const {name} = node;
    const {start, end} = node.loc;

    if (name === "NULL" || name === "nullptr") {
        replacements.push({
            start,
            end,
            replace: "nil"
        });
    } else if (/^(?=al_|AL)/.test(name)) {
        replacements.push({
            start,
            end,
            replace: `${ libname }.${ name }`
        });
    } else if (LUA_KEYWORDS.has(name)) {
        replacements.push({
            start,
            end,
            replace: `_${ name }`
        });
    }
};

replacers.IfStatement = (parser, replacements, node, parents) => {
    const {input} = parser;
    const {
        identifier: ifkw,
        condition,
        statement,
        elsekw,
        alternative
    } = node;

    if (!condition.open || !condition.close) {
        throw new Error("There is something wrong");
    }

    replacements.push({
        start: condition.open.loc.start,
        end: condition.open.loc.end,
        replace: /\w/.test(input[condition.open.loc.start - 1]) ? " " : ""
    }, {
        start: condition.close.loc.start,
        end: condition.close.loc.end,
        replace: /\w/.test(input[condition.close.loc.end + 1]) ? " " : ""
    });

    addStatementReplacement(input, statement, "then", replacements);

    if (alternative) {
        const replacement = replacements.at(-1);
        replacement.replace = "";

        let {start} = replacement;
        while (start > 0 && /^\s/.test(input[start - 1])) {
            start--;
        }
        replacement.start = start;
    }

    if (alternative instanceof IfStatement) {
        replacements.push({
            start: elsekw.loc.start,
            end: alternative.identifier.loc.end,
            replace: "elseif"
        });
    } else if (alternative) {
        addStatementReplacement(input, alternative, "", replacements);
    }

    if (alternative && !(alternative.open && alternative.close)) {
        setLastReplacementIndent(input, elsekw, replacements);
    }

    if (!alternative && !(statement.open && statement.close)) {
        setLastReplacementIndent(input, ifkw, replacements);
    }
};

replacers.LogicalExpression = (parser, replacements, node, parents) => {
    const {input} = parser;
    const {expressions} = node;

    for (let i = expressions.length - 2; i >= 0; i -= 2) {
        const operator = expressions[i];
        if (!(operator instanceof OperatorExpression)) {
            throw new Error("There is something wrong");
        }

        if (operator.operator === "&&") {
            addOperatorReplacement(input, operator, "and", replacements);
        } else if (operator.operator === "||") {
            addOperatorReplacement(input, operator, "or", replacements);
        } else if (operator.operator === "!=") {
            addOperatorReplacement(input, operator, "~=", replacements);
        } else if (operator.operator === "!") {
            addOperatorReplacement(input, operator, "not", replacements);
        } else if (BIT_OPERATIONS_MAP.has(operator.operator)) {
            const lhs = expressions[i - 1];
            const rhs = expressions.at(-1);
            addBitOperationReplacement(input, BIT_OPERATIONS_MAP.get(operator.operator), operator, lhs, rhs, replacements);
        }
    }
};

replacers.PostfixExpression = (parser, replacements, node, parents) => {
    const {input} = parser;
    const {primary, accessors} = node;

    if (accessors.at(-1) instanceof OperatorExpression) {
        const operator = accessors.at(-1);
        if (operator.operator === "++" || operator.operator === "--") {
            const op = operator.operator[0];
            const expression = getReplacedInput(input, replacements, primary.loc.start, accessors.length > 1 ? accessors.at(-2).loc.end : primary.loc.end);

            replacements.push({
                start: operator.loc.start,
                end: operator.loc.end,
                replace: ` = ${ expression } ${ op } 1`
            });
        }
    }
};

replacers.StringLiteralList = (parser, replacements, node, parents) => {
    const {literals} = node;
    for (const literal of literals.slice(1)) {
        replacements.push({
            start: literal.loc.start,
            end: literal.loc.start,
            replace: ".. "
        });
    }
};

replacers.StringLiteral = (parser, replacements, node, parents) => {
    const {value} = node;
    if (value.startsWith("\"data/")) {
        replacements.push({
            start: node.loc.start,
            end: node.loc.start + "\"data/".length,
            replace: "env.ALLEGRO_EXAMPLES_DATA_PATH .. \"/"
        });
    } else if (value.includes("data/")) {
        const pos = value.indexOf("data/");
        replacements.push({
            start: node.loc.start + pos,
            end: node.loc.start + pos + "data/".length,
            replace: "\" .. env.ALLEGRO_EXAMPLES_DATA_PATH .. \"/"
        });
    }
};

replacers.SwitchStatement = (parser, replacements, node, parents) => {
    const {input} = parser;

    const {statement} = node;

    // statement instanceof CompoundStatement
    if (!(statement instanceof CompoundStatement) || statement.blocks.length === 0 || !(statement.blocks[0] instanceof CaseLabeledStatement)) {
        return;
    }

    const cases = [];

    for (const block of statement.blocks) {
        if (block instanceof CaseLabeledStatement || block instanceof DefaultLabeledStatement) {
            cases.push({
                condition: block,
                blocks: block.statement instanceof CompoundStatement ? block.statement.blocks.slice() : [block.statement]
            });
        } else {
            cases.at(-1).blocks.push(block);
        }
    }

    const getCaseLastStatements = (block, blocks = []) => {
        if (!block) {
            return blocks;
        }

        while (block instanceof CompoundStatement) {
            block = block.blocks.at(-1);
        }

        if (block instanceof BreakStatement || block instanceof ReturnStatement) {
            blocks.push(block);
        } else if (block instanceof IfStatement) {
            getCaseLastStatements(block.statement, blocks);
            getCaseLastStatements(block.alternative, blocks);
        }

        return blocks;
    };

    const isValidCaseLastStatement = block => {
        if (!block) {
            return false;
        }

        while (block instanceof CompoundStatement) {
            block = block.blocks.at(-1);
        }

        if (block instanceof BreakStatement || block instanceof ReturnStatement) {
            return true;
        }

        if (block instanceof IfStatement) {
            return isValidCaseLastStatement(block.statement) && isValidCaseLastStatement(block.alternative);
        }

        return false;
    };

    let valid = true;

    const invalidBreakStatementVisitor = (condition, bnode, bparents) => {
        if (!valid || !(bnode instanceof BreakStatement)) {
            return;
        }

        // get the corresponding parent: for, while, do while, case
        for (let i = bparents.length - 1; i >= 0; i--) {
            const parent = bparents[i];
            if (
                parent instanceof CaseLabeledStatement ||
                parent instanceof DoWhileStatement ||
                parent instanceof ForStatement ||
                parent instanceof SwitchStatement ||
                parent instanceof WhileStatement
            ) {
                if (parent instanceof CaseLabeledStatement && parent === condition || parent instanceof SwitchStatement && parent === node) {
                    valid = false;
                }
                break;
            }
        }
    };

    for (const {
        condition,
        blocks
    } of cases) {
        // All cases must end with a break or eturn statement except for default statement
        if (!(condition instanceof DefaultLabeledStatement) && !isValidCaseLastStatement(blocks.at(-1))) {
            return;
        }

        // All cases must have a unique break statement
        const bstatement = getCaseLastStatements(blocks.at(-1));

        for (const block of blocks) {
            if (!valid) {
                break;
            }

            if (bstatement.includes(block)) {
                continue;
            }

            block.visit(invalidBreakStatementVisitor.bind(null, condition));
        }

        if (!valid) {
            return;
        }
    }

    const expr = getReplacedInput(input, replacements, node.expression.expression.loc.start, node.expression.expression.loc.end);

    for (const {
        condition,
        blocks
    } of cases) {
        if (condition instanceof DefaultLabeledStatement) {
            //  replace 'default' with 'else', ':' with 'then'

            replacements.push({
                start: condition.identifier.loc.start,
                end: condition.identifier.loc.end,
                replace: "else"
            });

            replacements.push({
                start: condition.colon.loc.start,
                end: condition.colon.loc.end,
                replace: /\w/.test(input[condition.colon.loc.start - 1]) ? " " : ""
            });
        } else {
            //  replace 'case' with 'if expr == ', ':' with 'then'

            replacements.push({
                start: condition.identifier.loc.start,
                end: condition.identifier.loc.end,
                replace: `${ cases[0].condition === condition ? "" : "else" }if ${ expr } ==`
            });

            replacements.push({
                start: condition.colon.loc.start,
                end: condition.colon.loc.end,
                replace: `${ /\w/.test(input[condition.colon.loc.start - 1]) ? " " : "" }then${ /\w/.test(input[condition.colon.loc.end + 1]) ? " " : "" }`
            });
        }

        //  remove last break statement
        for (const bstatement of getCaseLastStatements(blocks.at(-1))) {
            if (bstatement instanceof BreakStatement) {
                replacements.push({
                    start: bstatement.loc.start,
                    end: bstatement.loc.end,
                    replace: ""
                });
            }
        }

        if (condition.statement instanceof CompoundStatement) {
            if (blocks.length === condition.statement.blocks.length) {
                // block if unique compound statement, remove '{', '}'
                const {open, close} = condition.statement;

                replacements.push({
                    start: open.loc.start,
                    end: open.loc.end,
                    replace: ""
                });

                replacements.push({
                    start: close.loc.start,
                    end: close.loc.end,
                    replace: ""
                });
            } else {
                wrapCompoundStatement(replacements, condition.statement);
            }
        }
    }

    // remove switch () {
    replacements.push({
        start: node.identifier.loc.start,
        end: statement.open.loc.end,
        replace: ""
    });

    //  replace switch '}' with 'end'
    replacements.push({
        start: statement.close.loc.start,
        end: statement.close.loc.end,
        replace: `${ /\w/.test(input[statement.close.loc.start - 1]) ? " " : "" }end${ /\w/.test(input[statement.close.loc.end + 1]) ? " " : "" }`
    });
};

replacers.UnaryExpression = (parser, replacements, node, parents) => {
    const {input} = parser;
    const {operator, expression} = node;
    const {start, end} = operator.loc;

    if (operator.operator === "!") {
        addOperatorReplacement(input, operator, "not", replacements);
    } else if (operator.operator === "~") {
        replacements.push({
            start,
            end,
            replace: ""
        });

        replacements.push({
            start: expression.loc.start,
            end: expression.loc.end,
            replace: `bit.bnot(${ getReplacedInput(input, replacements, expression.loc.start, expression.loc.end) })`
        });
    } else if (operator.operator === "&") {
        replacements.push({
            start,
            end,
            replace: ""
        });
    } else if (operator.operator === "++" || operator.operator === "--") {
        const op = operator.operator[0];
        const expr = getReplacedInput(input, replacements, expression.loc.start, expression.loc.end);

        replacements.push({
            start: node.loc.start,
            end: node.loc.end,
            replace: `${ expr } = ${ expr } ${ op } 1`
        });
    }
};

replacers.WhileStatement = (parser, replacements, node, parents) => {
    const {input} = parser;

    const {
        identifier,
        condition,
        statement
    } = node;

    replacements.push({
        start: condition.open.loc.start,
        end: condition.open.loc.end,
        replace: " "
    }, {
        start: condition.close.loc.start,
        end: condition.close.loc.end,
        replace: " "
    });

    addStatementReplacement(input, statement, "do", replacements);

    if (!(statement.open && statement.close)) {
        setLastReplacementIndent(input, identifier, replacements);
    }
};

const excludeNode = node => {
    if (node instanceof StructOrUnionSpecifier) {
        return true;
    }

    if (node instanceof Declaration) {
        const {specifiers} = node;
        if (specifiers[0] instanceof Identifier && specifiers[0].name === "typedef") {
            return true;
        }

        if (node.declarators.length === 0 && specifiers[0] instanceof StructOrUnionSpecifier) {
            return true;
        }
    }

    return false;
};

const rewrite_c = (filename, types, code) => {
    const parser = new Parser();

    const unit = parser.parse(code
        .replace(/#define[^\S\r\n]+(\w+)([^\S\r\n]+.+)/g, "static __auto__ $1 = $2;")
        .replace(/#(define|undef|include|ifn?def|endif|if|elif|else)\b/g, "// #$1")
    , {
        filename,
        typedefs: new Set([
            ...typedefs,
            ...types,
            "bool",
            "__auto__",
        ])
    });

    const {comments, input} = parser;

    const replacements = [];

    addCommentsReplacement(input, comments, replacements);

    unit.visit((node, parents) => {
        if (excludeNode(node) || parents.some(excludeNode)) {
            return;
        }

        const replacer = replacers[node.constructor.name];

        if (typeof replacer === "function") {
            replacer(parser, replacements, node, parents);
        }
    });

    const pos = filename.indexOf("/allegro5/");
    const source = pos === -1 ? filename : `https://github.com/liballeg/allegro5/blob/5.2.11.0/${ filename.slice(pos + "/allegro5/".length) }`;

    return `
#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    ${ source }
--]]

local allegro5_lua = require("allegro5_lua")
local ${ libname } = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local open_log_monospace = common.open_log_monospace
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: undefined-global
    ${ libname } = require("allegro5_lua.al5_ffi")()
end

${ getReplacedInput(input, replacements, 0, input.length) }

    `.trim();
};

const convert = (code, filename, output, types) => {
    const converted = [
        rewrite_c.bind(null, filename, types),
    ].reduce((code, pipeline, index) => {
        return pipeline(code);
    }, code);

    if (output === "-") {
        console.log(converted);
        return;
    }

    fs.writeFile(output, converted, err => {
        if (err) {
            throw err;
        }
    });
};

if (require.main === module) {
    const flags = new Set([
        "-",
        "--help",
    ]);

    const oneValueArgs = new Set([
        "--file",
        "--output",
        "--libname",
    ]);

    const multiValueArgs = new Set([
        "--type",
    ]);

    const aliases = new Map([
        ["-?", "--help"],
        ["-h", "--help"],
        ["-f", "--file"],
        ["-o", "--output"],
        ["-l", "--libname"],
        ["-t", "--type"],
    ]);

    const options = new Map();
    const unparsed = [];

    let key, value;
    let has_key = false;
    let has_value = false;
    for (const arg of process.argv.slice(2)) {
        if (has_key) {
            has_value = true;
            value = arg;
        } else if (arg.includes("=")) {
            has_key = true;
            has_value = true;

            const eq = arg.indexOf("=");
            key = arg.slice(0, eq);
            value = arg.slice(eq + 1);
        } else {
            has_key = true;
            has_value = false;
            key = arg;
        }

        if (aliases.has(key)) {
            key = aliases.get(key);
        }

        if (flags.has(key)) {
            options.set(key, true);
        } else if (oneValueArgs.has(key)) {
            if (options.has(key) && options.get(key) !== undefined) {
                throw new Error(`'${ key }' has been specified multiple times`);
            }

            if (!has_value) {
                options.set(key, undefined);
                continue;
            }

            options.set(key, value);
        } else if (multiValueArgs.has(key)) {
            if (!options.has(key)) {
                options.set(key, []);
            }

            if (!has_value) {
                continue;
            }

            options.get(key).push(value);
        } else {
            unparsed.push(arg);
        }

        has_key = false;
        has_value = false;
    }

    if (unparsed.length !== 0) {
        throw new Error(`Unparsed arguments ${ JSON.stringify(unparsed) }`);
    }

    if (options.has("--help")) {
        process.stderr.write(`${ `
Usage:
node ${ __filename } [options...]

Options:
    -?,-h,--help            : Show this help
    -f, --file <file>       : Read from file instead of stdin. Use '-' to read from stdin
    -o, --output <file>     : Write to file instead of stdout. Use '-' to write to stdout
    -l, --libname <name>    : Module name
`.trim() }\n`);
        return;
    }

    const filename = options.has("--file") ? options.get("--file") : "-";
    const output = options.has("--output") ? options.get("--output") : "-";
    const types = options.has("--type") ? options.get("--type") : [];
    libname = options.has("--libname") ? options.get("--libname") : "allegro5";

    if (filename === "-") {
        const buffers = [];
        process.stdin.resume();
        process.stdin.setEncoding("utf8");
        process.stdin.on("data", buffers.push.bind(buffers));
        process.stdin.on("end", () => {
            convert(buffers.join(""), filename, output, types);
        });
    } else {
        fs.readFile(filename, (err, buffer) => {
            convert(buffer.toString(), filename, output, types);
        });
    }
}
