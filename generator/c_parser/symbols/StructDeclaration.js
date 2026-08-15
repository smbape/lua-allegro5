class StructDeclaration {
    constructor({
        visibility,
        virtual,
        type,
        qualifiers,
        declarators, // comma separated declarators
        semicolon
    }, loc) {
        this.visibility = visibility;
        this.virtual = virtual;
        this.type = type;
        this.qualifiers = qualifiers;
        this.declarators = declarators;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        if (this.visibility) {
            this.visibility.visit(cb, parents);
        }

        if (this.virtual) {
            this.virtual.visit(cb, parents);
        }

        if (this.type) {
            this.type.visit(cb, parents);
        }

        for (const qualifier of this.qualifiers) {
            qualifier.visit(cb, parents);
        }

        for (const declarator of this.declarators) {
            declarator.visit(cb, parents);
        }

        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.StructDeclaration = StructDeclaration;
