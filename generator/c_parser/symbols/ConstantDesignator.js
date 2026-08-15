class ConstantDesignator {
    constructor({
        open,
        expression,
        close
    }, loc) {
        this.open = open;
        this.expression = expression;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);
        this.expression.visit(cb, parents);
        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ConstantDesignator = ConstantDesignator;
