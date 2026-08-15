class InitializerExpression {
    constructor({
        open,
        initializers,
        comma,
        close
    }, loc) {
        this.open = open;
        this.initializers = initializers;
        this.comma = comma;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        for (const initializer of this.initializers) {
            initializer.visit(cb, parents);
        }

        if (this.comma) {
            this.comma.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.InitializerExpression = InitializerExpression;
