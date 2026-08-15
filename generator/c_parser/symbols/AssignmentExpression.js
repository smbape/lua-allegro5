class AssignmentExpression {
    constructor({
        unary,
        operator,
        expression
    }, loc) {
        this.unary = unary;
        this.operator = operator;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.unary.visit(cb, parents);
        this.operator.visit(cb, parents);
        this.expression.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.AssignmentExpression = AssignmentExpression;
