class ParameterDeclaration {
    constructor({
        specifiers,
        declarator,
        equals,
        initializer
    }, loc) {
        this.specifiers = specifiers;
        this.declarator = declarator;
        this.equals = equals;
        this.initializer = initializer;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const specifier of this.specifiers) {
            specifier.visit(cb, parents);
        }

        if (this.declarator) {
            this.declarator.visit(cb, parents);
        }

        if (this.equals) {
            this.equals.visit(cb, parents);
        }

        if (this.initializer) {
            this.initializer.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.ParameterDeclaration = ParameterDeclaration;
