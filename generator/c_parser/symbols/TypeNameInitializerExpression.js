class TypeNameInitializerExpression {
    constructor({
        typename,
        expression
    }, loc) {
        this.typename = typename;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.typename.visit(cb, parents);
        this.expression.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.TypeNameInitializerExpression = TypeNameInitializerExpression;
