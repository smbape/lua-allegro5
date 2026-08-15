class InitDeclarator {
    constructor({
        declarator,
        equals,
        initializer
    }, loc) {
        this.declarator = declarator;
        this.equals = equals;
        this.initializer = initializer;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.declarator.visit(cb, parents);
        this.equals.visit(cb, parents);
        this.initializer.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.InitDeclarator = InitDeclarator;
