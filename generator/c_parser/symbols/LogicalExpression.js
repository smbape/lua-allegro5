class LogicalExpression {
    constructor(expressions, loc) {
        this.expressions = expressions;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const expression of this.expressions) {
            expression.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.LogicalExpression = LogicalExpression;
