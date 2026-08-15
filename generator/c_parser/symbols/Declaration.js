class Declaration {
    constructor({
        specifiers,
        declarators,
        semicolon
    }, loc) {
        this.specifiers = specifiers;
        this.declarators = declarators;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const specifier of this.specifiers) {
            specifier.visit(cb, parents);
        }

        for (const declarator of this.declarators) {
            declarator.visit(cb, parents);
        }

        if (this.semicolon) {
            this.semicolon.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.Declaration = Declaration;
