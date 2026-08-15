class TypeName {
    constructor({
        qualifiers,
        type,
        declarator
    }, loc) {
        this.qualifiers = qualifiers;
        this.type = type;
        this.declarator = declarator;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const qualifier of this.qualifiers) {
            qualifier.visit(cb, parents);
        }

        this.type.visit(cb, parents);

        if (this.declarator) {
            this.declarator.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.TypeName = TypeName;
