class FunctionDefinition {
    constructor({
        virtual,
        destructor,
        specifiers,
        declarator,
        declarations,
        statement
    }, loc) {
        this.virtual = virtual;
        this.destructor = destructor;
        this.specifiers = specifiers;
        this.declarator = declarator;
        this.declarations = declarations;
        this.statement = statement;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        if (this.virtual) {
            this.virtual.visit(cb, parents);
        }

        if (this.destructor) {
            this.destructor.visit(cb, parents);
        }

        for (const specifier of this.specifiers) {
            specifier.visit(cb, parents);
        }

        this.declarator.visit(cb, parents);

        for (const declaration of this.declarations) {
            declaration.visit(cb, parents);
        }

        if (this.statement) {
            this.statement.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.FunctionDefinition = FunctionDefinition;
