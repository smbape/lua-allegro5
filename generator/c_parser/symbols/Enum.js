class Enum {
    constructor({
        enumkw,
        identifier,
        open,
        enumerators,
        comma,
        close
    }, loc) {
        this.enumkw = enumkw;
        this.identifier = identifier;
        this.open = open;
        this.enumerators = enumerators;
        this.comma = comma;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.enumkw.visit(cb, parents);

        if (this.identifier) {
            this.identifier.visit(cb, parents);
        }

        if (this.enumerators) {
            this.open.visit(cb, parents);

            for (const enumerator of this.enumerators) {
                enumerator.visit(cb, parents);
            }

            if (this.comma) {
                this.comma.visit(cb, parents);
            }

            this.close.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.Enum = Enum;
