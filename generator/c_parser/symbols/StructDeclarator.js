class StructDeclarator {
    constructor({
        declarator,
        colon,
        expression
    }, loc) {
        this.declarator = declarator;
        this.colon = colon;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.declarator.visit(cb, parents);

        if (this.colon) {
            this.colon.visit(cb, parents);
        }

        if (this.expression) {
            this.expression.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.StructDeclarator = StructDeclarator;
