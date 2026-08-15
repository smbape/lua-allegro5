class ExpressionStatement {
    constructor({
        expression,
        semicolon
    }, loc) {
        this.expression = expression;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.expression.visit(cb, parents);
        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ExpressionStatement = ExpressionStatement;
