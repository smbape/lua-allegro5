class PostfixExpression {
    constructor({
        primary,
        accessors
    }, loc) {
        this.primary = primary;
        this.accessors = accessors;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.primary.visit(cb, parents);

        for (const accessor of this.accessors) {
            accessor.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.PostfixExpression = PostfixExpression;
