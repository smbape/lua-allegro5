class StructOrUnionSpecifier {
    constructor({
        specifier,
        identifier,
        open,
        declarations,
        close
    }, loc) {
        this.specifier = specifier;
        this.identifier = identifier;
        this.open = open;
        this.declarations = declarations;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.specifier.visit(cb, parents);

        if (this.identifier) {
            this.identifier.visit(cb, parents);
        }

        if (this.declarations) {
            for (const declaration of this.declarations) {
                declaration.visit(cb, parents);
            }
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.StructOrUnionSpecifier = StructOrUnionSpecifier;
