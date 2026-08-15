class OperatorExpression {
    constructor(operator, loc) {
        this.operator = operator;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.OperatorExpression = OperatorExpression;
