class CaseLabeledStatement {
    constructor({
        identifier,
        expression,
        colon,
        statement
    }, loc) {
        this.identifier = identifier;
        this.expression = expression;
        this.colon = colon;
        this.statement = statement;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.expression.visit(cb, parents);
        this.colon.visit(cb, parents);
        this.statement.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.CaseLabeledStatement = CaseLabeledStatement;
