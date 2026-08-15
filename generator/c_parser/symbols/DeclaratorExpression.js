class DeclaratorExpression {
    constructor({
        open,
        declarator,
        close
    }, loc) {
        this.open = open;
        this.declarator = declarator;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);
        this.declarator.visit(cb, parents);
        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.DeclaratorExpression = DeclaratorExpression;
